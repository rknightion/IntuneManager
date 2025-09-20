import Foundation
import SwiftUI
import Combine

@MainActor
class BulkAssignmentViewModel: ObservableObject {
    @Published var selectedApplications: Set<Application> = []
    @Published var selectedGroups: Set<DeviceGroup> = []
    @Published var assignmentIntent: Assignment.AssignmentIntent = .required
    @Published var assignmentSettings: Assignment.AssignmentSettings?
    @Published var isProcessing = false
    @Published var progress: AssignmentService.AssignmentProgress?
    @Published var error: Error?
    @Published var completedAssignments: [Assignment] = []
    @Published var failedAssignments: [Assignment] = []

    private let assignmentService = AssignmentService.shared
    private var cancellables = Set<AnyCancellable>()

    var totalAssignments: Int {
        selectedApplications.count * selectedGroups.count
    }

    var isValid: Bool {
        !selectedApplications.isEmpty && !selectedGroups.isEmpty
    }

    var estimatedTime: String {
        let seconds = totalAssignments * 2 // Rough estimate
        let minutes = seconds / 60
        if minutes < 1 {
            return "< 1 minute"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
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
    }

    func executeAssignment() async {
        guard isValid else { return }

        isProcessing = true
        defer { isProcessing = false }

        let operation = BulkAssignmentOperation(
            applications: Array(selectedApplications),
            groups: Array(selectedGroups),
            intent: assignmentIntent,
            settings: assignmentSettings
        )

        do {
            let assignments = try await assignmentService.performBulkAssignment(operation)
            completedAssignments = assignments
            Logger.shared.info("Bulk assignment completed: \(assignments.count) successful")
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
        completedAssignments.removeAll()
        failedAssignments.removeAll()
        error = nil
        progress = nil
    }

    func retryFailedAssignments() async {
        guard !failedAssignments.isEmpty else { return }

        do {
            let retried = try await assignmentService.retryFailedAssignments()
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