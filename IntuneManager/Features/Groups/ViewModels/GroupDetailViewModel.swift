import Foundation
import SwiftUI
import Combine

@MainActor
final class GroupDetailViewModel: ObservableObject {
    @Published var group: DeviceGroup
    @Published var members: [GroupMember] = []
    @Published var owners: [GroupOwner] = []
    @Published var assignedApps: [Application] = []

    @Published var isLoadingMembers = false
    @Published var isLoadingOwners = false
    @Published var isLoadingAssignments = false

    @Published var errorMessage: String?

    private let groupService = GroupService.shared
    private let appService = ApplicationService.shared

    init(group: DeviceGroup) {
        self.group = group

        // If group already has owners from the list view, use them
        if let existingOwners = group.owners {
            self.owners = existingOwners
        }

        // If group already has members, use them
        if let existingMembers = group.members {
            self.members = existingMembers
        }
    }

    // MARK: - Load Members

    func loadMembers() async {
        guard !isLoadingMembers else {
            Logger.shared.debug("Already loading members, skipping", category: .ui)
            return
        }

        // Skip built-in targets
        if group.isBuiltInAssignmentTarget {
            Logger.shared.debug("Skipping member load for built-in target", category: .ui)
            return
        }

        Logger.shared.info("Loading members for group: \(group.displayName) (ID: \(group.id))", category: .ui)
        isLoadingMembers = true
        errorMessage = nil

        do {
            let fetchedMembers = try await groupService.fetchGroupMembers(groupId: group.id)
            members = fetchedMembers
            Logger.shared.info("Successfully loaded \(fetchedMembers.count) members", category: .ui)
        } catch {
            Logger.shared.error("Failed to load members: \(error.localizedDescription)", category: .ui)
            errorMessage = "Failed to load members: \(error.localizedDescription)"
        }

        isLoadingMembers = false
    }

    // MARK: - Load Owners

    func loadOwners() async {
        guard !isLoadingOwners else {
            Logger.shared.debug("Already loading owners, skipping", category: .ui)
            return
        }

        // Skip if already loaded
        if !owners.isEmpty {
            Logger.shared.debug("Owners already loaded, skipping", category: .ui)
            return
        }

        // Skip built-in targets
        if group.isBuiltInAssignmentTarget {
            Logger.shared.debug("Skipping owner load for built-in target", category: .ui)
            return
        }

        Logger.shared.info("Loading owners for group: \(group.displayName) (ID: \(group.id))", category: .ui)
        isLoadingOwners = true
        errorMessage = nil

        do {
            let fetchedOwners = try await groupService.fetchGroupOwners(groupId: group.id)
            owners = fetchedOwners
            Logger.shared.info("Successfully loaded \(fetchedOwners.count) owners", category: .ui)
        } catch {
            Logger.shared.error("Failed to load owners: \(error.localizedDescription)", category: .ui)
            errorMessage = "Failed to load owners: \(error.localizedDescription)"
        }

        isLoadingOwners = false
    }

    // MARK: - Load Assignments

    func loadAssignments() async {
        guard !isLoadingAssignments else {
            Logger.shared.debug("Already loading assignments, skipping", category: .ui)
            return
        }

        Logger.shared.info("Loading assignments for group: \(group.displayName) (ID: \(group.id))", category: .ui)
        isLoadingAssignments = true
        errorMessage = nil

        // Get all applications and filter by those assigned to this group
        let allApps = appService.applications

        let appsForGroup = allApps.filter { app in
            guard let assignments = app.assignments else { return false }
            return assignments.contains { assignment in
                assignment.target.groupId == group.id
            }
        }

        assignedApps = appsForGroup.sorted { $0.displayName < $1.displayName }
        Logger.shared.info("Successfully loaded \(appsForGroup.count) assigned applications", category: .ui)

        isLoadingAssignments = false
    }

    // MARK: - Refresh All

    func refreshAll() async {
        Logger.shared.info("Refreshing all group details", category: .ui)

        // Load all three sections concurrently
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.loadMembers()
            }

            group.addTask {
                await self.loadOwners()
            }

            group.addTask {
                await self.loadAssignments()
            }
        }

        Logger.shared.info("Completed refreshing all group details", category: .ui)
    }
}
