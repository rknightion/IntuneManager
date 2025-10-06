import Foundation
import SwiftUI
import Combine

@MainActor
class BulkAssignmentViewModel: ObservableObject {
    @Published var selectedApplications: Set<Application> = []
    @Published var selectedGroups: Set<DeviceGroup> = []
    @Published var assignmentIntent: Assignment.AssignmentIntent = .required
    @Published var assignmentSettings: Assignment.AssignmentSettings?
    @Published var groupAssignmentSettings: [GroupAssignmentSettings] = []
    @Published var targetPlatform: Application.DevicePlatform?
    @Published var isProcessing = false
    @Published var progress: AssignmentService.AssignmentProgress?
    @Published var error: Error?
    @Published var completedAssignments: [Assignment] = []
    @Published var failedAssignments: [Assignment] = []

    private let assignmentService = AssignmentService.shared
    private var cancellables = Set<AnyCancellable>()

    // Count of actual assignments in Intune for selected apps
    var totalExistingAssignments: Int {
        selectedApplications.reduce(0) { total, app in
            total + app.assignmentCount
        }
    }

    // Count of new assignments to be created
    var totalNewAssignments: Int {
        selectedApplications.count * selectedGroups.count
    }

    // For backwards compatibility - return new assignments count
    var totalAssignments: Int {
        totalNewAssignments
    }

    var isValid: Bool {
        !selectedApplications.isEmpty && !selectedGroups.isEmpty
    }

    var estimatedTime: String {
        let seconds = totalNewAssignments * 2 // Rough estimate
        let minutes = seconds / 60
        if minutes < 1 {
            return "< 1 minute"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    // Get all existing group assignments for the selected applications
    var existingAssignmentGroups: Set<String> {
        var groupIds = Set<String>()
        for app in selectedApplications {
            if let assignments = app.assignments {
                for assignment in assignments {
                    if let groupId = assignment.target.groupId {
                        groupIds.insert(groupId)
                    }
                }
            }
        }
        return groupIds
    }

    // Check if a group already has assignments for all selected apps
    func isGroupFullyAssigned(_ group: DeviceGroup) -> Bool {
        guard !selectedApplications.isEmpty else { return false }

        for app in selectedApplications {
            let hasAssignment = app.assignments?.contains { assignment in
                assignment.target.groupId == group.id
            } ?? false

            if !hasAssignment {
                return false
            }
        }
        return true
    }

    // Get assignment details for display
    func getAssignmentSummaryText() -> String {
        let existingCount = totalExistingAssignments
        let newCount = totalNewAssignments

        if existingCount > 0 && newCount > 0 {
            return "\(existingCount) existing, \(newCount) new to create"
        } else if existingCount > 0 {
            return "\(existingCount) existing assignments"
        } else if newCount > 0 {
            return "\(newCount) new assignments to create"
        } else {
            return "No assignments"
        }
    }

    // Compute available platforms from selected applications
    var availablePlatforms: Set<Application.DevicePlatform> {
        guard !selectedApplications.isEmpty else { return [] }

        // Get the intersection of all supported platforms
        let platformSets = selectedApplications.map { $0.supportedPlatforms }
        guard let firstSet = platformSets.first else { return [] }

        return platformSets.dropFirst().reduce(firstSet) { result, platforms in
            result.intersection(platforms)
        }
    }

    init() {
        setupBindings()
    }

    private func setupBindings() {
        assignmentService.$currentProgress
            .receive(on: DispatchQueue.main)
            .assign(to: &$progress)

        assignmentService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)

        assignmentService.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isProcessing)

        // Initialize group settings when groups are selected
        $selectedGroups
            .sink { [weak self] groups in
                self?.updateGroupSettings(for: groups)
            }
            .store(in: &cancellables)
    }

    private func updateGroupSettings(for groups: Set<DeviceGroup>) {
        // Remove settings for deselected groups
        groupAssignmentSettings.removeAll { setting in
            !groups.contains { $0.id == setting.groupId }
        }

        // Add settings for new groups
        let existingGroupIds = Set(groupAssignmentSettings.map { $0.groupId })
        for group in groups {
            if !existingGroupIds.contains(group.id) {
                let appType = primaryAppType
                let newSettings = GroupAssignmentSettings(
                    groupId: group.id,
                    groupName: group.displayName,
                    appType: appType,
                    intent: assignmentIntent
                )
                groupAssignmentSettings.append(newSettings)
            }
        }
    }

    // Determine the primary app type from selected applications
    var primaryAppType: Application.AppType {
        guard !selectedApplications.isEmpty else { return .unknown }
        let appTypes = selectedApplications.map { $0.appType }
        let typeCount = Dictionary(grouping: appTypes, by: { $0 }).mapValues { $0.count }
        return typeCount.max(by: { $0.value < $1.value })?.key ?? .unknown
    }

    func executeAssignment() async {
        guard isValid else { return }

        isProcessing = true
        defer { isProcessing = false }

        // Create stable copies of the data before any context changes
        let appDataCopy = selectedApplications.map {
            (id: $0.id, displayName: $0.displayName, supportedPlatforms: $0.supportedPlatforms)
        }
        let groupDataCopy = selectedGroups.map {
            (id: $0.id, displayName: $0.displayName, isBuiltIn: $0.isBuiltInAssignmentTarget, targetType: $0.assignmentTargetType)
        }

        // Create simple Application/DeviceGroup structs that won't have SwiftData issues
        let stableApps = appDataCopy.map { appData in
            let app = Application(
                id: appData.id,
                displayName: appData.displayName,
                appType: .unknown,
                createdDateTime: Date(),
                lastModifiedDateTime: Date()
            )
            return app
        }

        let stableGroups = groupDataCopy.map { groupData in
            DeviceGroup(
                id: groupData.id,
                displayName: groupData.displayName
            )
        }

        let operation = BulkAssignmentOperation(
            applications: stableApps,
            groups: stableGroups,
            intent: assignmentIntent,
            settings: assignmentSettings,
            groupSettings: groupAssignmentSettings
        )

        do {
            let assignments = try await assignmentService.performBulkAssignment(operation)
            completedAssignments = assignments
            Logger.shared.info("Bulk assignment completed: \(assignments.count) successful")

            // Notify that assignments have changed
            NotificationCenter.default.post(name: .assignmentsDidChange, object: nil)
        } catch {
            self.error = error
            Logger.shared.error("Bulk assignment failed: \(error)")
        }
    }

    func cancelAssignment() {
        assignmentService.cancelActiveAssignments()
        reset()
    }

    func reset() {
        selectedApplications.removeAll()
        selectedGroups.removeAll()
        assignmentIntent = .required
        assignmentSettings = nil
        groupAssignmentSettings.removeAll()
        targetPlatform = nil
        completedAssignments.removeAll()
        failedAssignments.removeAll()
        error = nil
        progress = nil
    }

    func retryFailedAssignments(selective: Bool = true) async {
        guard !failedAssignments.isEmpty else { return }

        do {
            let retried = try await assignmentService.retryFailedAssignments(selective: selective)
            completedAssignments.append(contentsOf: retried)
            failedAssignments.removeAll { assignment in
                retried.contains { $0.id == assignment.id }
            }
        } catch {
            self.error = error
        }
    }

    // MARK: - Summary Data

    func getAssignmentSummary() -> AssignmentSummary {
        var appSummary: [String: Int] = [:]
        var groupSummary: [String: Int] = [:]

        for app in selectedApplications {
            appSummary[app.displayName] = selectedGroups.count
        }

        for group in selectedGroups {
            groupSummary[group.displayName] = selectedApplications.count
        }

        return AssignmentSummary(
            totalAssignments: totalAssignments,
            applicationCount: selectedApplications.count,
            groupCount: selectedGroups.count,
            intent: assignmentIntent,
            appSummary: appSummary,
            groupSummary: groupSummary,
            estimatedTime: estimatedTime
        )
    }

    struct AssignmentSummary {
        let totalAssignments: Int
        let applicationCount: Int
        let groupCount: Int
        let intent: Assignment.AssignmentIntent
        let appSummary: [String: Int]
        let groupSummary: [String: Int]
        let estimatedTime: String
    }
}