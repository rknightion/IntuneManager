import Foundation

/// Detects conflicts in assignment intents for applications
struct AssignmentConflictDetector {

    /// Represents a conflict between assignment intents
    struct AssignmentConflict: Identifiable {
        let id = UUID()
        let groupId: String
        let groupName: String
        let conflictType: ConflictType
        let assignments: [ConflictingAssignment]
        let severity: Severity
        let resolution: String

        struct ConflictingAssignment {
            let applicationName: String
            let intent: AppAssignment.AssignmentIntent
            let isExisting: Bool // true if existing, false if pending
        }

        enum ConflictType {
            case conflictingIntents  // e.g., Required and Uninstall for same group
            case redundantAssignment // e.g., Available and Required for same group
            case logicalConflict    // e.g., Available without enrollment + Required
            case crossAppConflict   // Different apps with incompatible intents for same group

            var displayName: String {
                switch self {
                case .conflictingIntents: return "Conflicting Intents"
                case .redundantAssignment: return "Redundant Assignment"
                case .logicalConflict: return "Logical Conflict"
                case .crossAppConflict: return "Cross-App Conflict"
                }
            }

            var icon: String {
                switch self {
                case .conflictingIntents: return "exclamationmark.triangle.fill"
                case .redundantAssignment: return "arrow.triangle.2.circlepath"
                case .logicalConflict: return "xmark.octagon.fill"
                case .crossAppConflict: return "arrow.triangle.branch"
                }
            }
        }

        enum Severity {
            case critical   // Must be resolved
            case warning    // Should be reviewed
            case info       // Informational only

            var color: String {
                switch self {
                case .critical: return "systemRed"
                case .warning: return "systemOrange"
                case .info: return "systemYellow"
                }
            }
        }
    }

    /// Detects all conflicts in the given assignments
    static func detectConflicts(
        currentAssignments: [AssignmentWithApp],
        pendingAssignments: [PendingAssignment],
        deletedAssignmentKeys: Set<String>,
        applicationNames: [String]
    ) -> [AssignmentConflict] {
        var conflicts: [AssignmentConflict] = []
        var groupAssignments: [String: [(appName: String, intent: AppAssignment.AssignmentIntent, isExisting: Bool)]] = [:]

        // Collect all assignments by group (excluding deleted ones)
        for item in currentAssignments {
            let key = "\(item.appId)_\(item.assignment.id)"
            if !deletedAssignmentKeys.contains(key) {
                let groupId = item.assignment.target.groupId ?? item.assignment.target.type.rawValue
                let groupName = item.assignment.target.groupName ?? item.assignment.target.type.displayName

                if groupAssignments[groupId] == nil {
                    groupAssignments[groupId] = []
                }
                groupAssignments[groupId]?.append((
                    appName: item.appName,
                    intent: item.assignment.intent,
                    isExisting: true
                ))
            }
        }

        // Add pending assignments for each app
        for pending in pendingAssignments {
            let groupId = pending.group.id

            for appName in applicationNames {
                if groupAssignments[groupId] == nil {
                    groupAssignments[groupId] = []
                }
                groupAssignments[groupId]?.append((
                    appName: appName,
                    intent: pending.intent,
                    isExisting: false
                ))
            }
        }

        // Check for conflicts within each group
        for (groupId, assignments) in groupAssignments {
            // Skip if only one assignment for the group
            guard assignments.count > 1 else { continue }

            let groupName = findGroupName(groupId: groupId, currentAssignments: currentAssignments, pendingAssignments: pendingAssignments)

            // Check for direct conflicts
            if let conflict = checkDirectConflicts(groupId: groupId, groupName: groupName, assignments: assignments) {
                conflicts.append(conflict)
            }

            // Check for redundant assignments
            if let conflict = checkRedundantAssignments(groupId: groupId, groupName: groupName, assignments: assignments) {
                conflicts.append(conflict)
            }

            // Check for logical conflicts
            if let conflict = checkLogicalConflicts(groupId: groupId, groupName: groupName, assignments: assignments) {
                conflicts.append(conflict)
            }
        }

        return conflicts
    }

    /// Check for direct conflicting intents (e.g., Required and Uninstall)
    private static func checkDirectConflicts(
        groupId: String,
        groupName: String,
        assignments: [(appName: String, intent: AppAssignment.AssignmentIntent, isExisting: Bool)]
    ) -> AssignmentConflict? {
        // Group assignments by app name to check for conflicts within the same app
        let appAssignments = Dictionary(grouping: assignments, by: { $0.appName })

        // Check each app for conflicting intents
        for (appName, appAssigns) in appAssignments {
            let appIntents = Set(appAssigns.map { $0.intent })

            // Check for Required vs Uninstall conflict for the same app
            if appIntents.contains(.required) && appIntents.contains(.uninstall) {
                let conflictingAssignments = appAssigns.compactMap { assignment -> AssignmentConflict.ConflictingAssignment? in
                    guard assignment.intent == .required || assignment.intent == .uninstall else { return nil }
                    return AssignmentConflict.ConflictingAssignment(
                        applicationName: assignment.appName,
                        intent: assignment.intent,
                        isExisting: assignment.isExisting
                    )
                }

                return AssignmentConflict(
                    groupId: groupId,
                    groupName: groupName,
                    conflictType: .conflictingIntents,
                    assignments: conflictingAssignments,
                    severity: .critical,
                    resolution: "Cannot have both 'Required' and 'Uninstall' intents for '\(appName)' assigned to the same group. Choose one intent."
                )
            }
        }

        return nil
    }

    /// Check for redundant assignments (e.g., Available and Required)
    private static func checkRedundantAssignments(
        groupId: String,
        groupName: String,
        assignments: [(appName: String, intent: AppAssignment.AssignmentIntent, isExisting: Bool)]
    ) -> AssignmentConflict? {
        // Group assignments by app name to check for redundancy within the same app
        let appAssignments = Dictionary(grouping: assignments, by: { $0.appName })

        // Check each app for redundant intents
        for (appName, appAssigns) in appAssignments {
            let appIntents = Set(appAssigns.map { $0.intent })

            // If Required is set, Available is redundant for the same app
            if appIntents.contains(.required) && appIntents.contains(.available) {
                let conflictingAssignments = appAssigns.compactMap { assignment -> AssignmentConflict.ConflictingAssignment? in
                    guard assignment.intent == .required || assignment.intent == .available else { return nil }
                    return AssignmentConflict.ConflictingAssignment(
                        applicationName: assignment.appName,
                        intent: assignment.intent,
                        isExisting: assignment.isExisting
                    )
                }

                return AssignmentConflict(
                    groupId: groupId,
                    groupName: groupName,
                    conflictType: .redundantAssignment,
                    assignments: conflictingAssignments,
                    severity: .warning,
                    resolution: "'Required' makes 'Available' redundant for '\(appName)'. Consider using only 'Required' for this group."
                )
            }
        }

        return nil
    }

    /// Check for logical conflicts (e.g., Available without enrollment + device group)
    private static func checkLogicalConflicts(
        groupId: String,
        groupName: String,
        assignments: [(appName: String, intent: AppAssignment.AssignmentIntent, isExisting: Bool)]
    ) -> AssignmentConflict? {
        // Group assignments by app name to check for logical conflicts within the same app
        let appAssignments = Dictionary(grouping: assignments, by: { $0.appName })

        // Check each app for logical conflicts
        for (appName, appAssigns) in appAssignments {
            let appIntents = Set(appAssigns.map { $0.intent })

            // Check for Available without enrollment + Required conflict for the same app
            if appIntents.contains(.availableWithoutEnrollment) && appIntents.contains(.required) {
                let conflictingAssignments = appAssigns.compactMap { assignment -> AssignmentConflict.ConflictingAssignment? in
                    guard assignment.intent == .availableWithoutEnrollment || assignment.intent == .required else { return nil }
                    return AssignmentConflict.ConflictingAssignment(
                        applicationName: assignment.appName,
                        intent: assignment.intent,
                        isExisting: assignment.isExisting
                    )
                }

                return AssignmentConflict(
                    groupId: groupId,
                    groupName: groupName,
                    conflictType: .logicalConflict,
                    assignments: conflictingAssignments,
                    severity: .critical,
                    resolution: "Cannot use 'Available without enrollment' with 'Required' for '\(appName)' assigned to the same group. Enrolled devices should use standard intents."
                )
            }
        }

        return nil
    }

    /// Find the group name for a given group ID
    private static func findGroupName(
        groupId: String,
        currentAssignments: [AssignmentWithApp],
        pendingAssignments: [PendingAssignment]
    ) -> String {
        // Try to find in current assignments
        if let existingAssignment = currentAssignments.first(where: {
            $0.assignment.target.groupId == groupId || $0.assignment.target.type.rawValue == groupId
        }) {
            return existingAssignment.assignment.target.groupName ?? existingAssignment.assignment.target.type.displayName
        }

        // Try to find in pending assignments
        if let pendingAssignment = pendingAssignments.first(where: { $0.group.id == groupId }) {
            return pendingAssignment.group.displayName
        }

        return groupId
    }

    /// Checks if a specific intent combination would cause a conflict
    static func wouldCauseConflict(
        newIntent: AppAssignment.AssignmentIntent,
        existingIntents: [AppAssignment.AssignmentIntent]
    ) -> (hasConflict: Bool, message: String?) {
        // Check for Required vs Uninstall
        if newIntent == .required && existingIntents.contains(.uninstall) {
            return (true, "Cannot assign 'Required' when 'Uninstall' is already assigned to this group")
        }
        if newIntent == .uninstall && existingIntents.contains(.required) {
            return (true, "Cannot assign 'Uninstall' when 'Required' is already assigned to this group")
        }

        // Check for Available without enrollment conflicts
        if newIntent == .availableWithoutEnrollment && existingIntents.contains(.required) {
            return (true, "Cannot use 'Available without enrollment' when 'Required' is already assigned")
        }
        if newIntent == .required && existingIntents.contains(.availableWithoutEnrollment) {
            return (true, "Cannot assign 'Required' when 'Available without enrollment' is already assigned")
        }

        // Warn about redundancy
        if newIntent == .available && existingIntents.contains(.required) {
            return (false, "Warning: 'Available' is redundant when 'Required' is already assigned")
        }

        return (false, nil)
    }
}