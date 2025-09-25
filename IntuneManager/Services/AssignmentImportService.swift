import Foundation
import SwiftUI
import Combine

@MainActor
final class AssignmentImportService: ObservableObject {
    static let shared = AssignmentImportService()

    @Published var importValidation: ImportValidation?
    @Published var isValidating = false

    private let applicationService = ApplicationService.shared
    private let groupService = GroupService.shared

    private init() {}

    /// Validation result for imports
    struct ImportValidation {
        let isValid: Bool
        let assignments: [ValidatedAssignment]
        let errors: [ImportError]
        let warnings: [ImportWarning]
        let summary: ImportSummary

        struct ValidatedAssignment {
            let original: AssignmentExportService.ExportableAssignment
            let applicationMatch: ApplicationMatch?
            let groupMatch: GroupMatch?
            let canImport: Bool
            let issues: [String]
        }

        struct ApplicationMatch {
            let id: String
            let name: String
            let matchType: MatchType

            enum MatchType {
                case exactId
                case exactName
                case fuzzyName(similarity: Double)
                case notFound
            }
        }

        struct GroupMatch {
            let id: String
            let name: String
            let matchType: MatchType

            enum MatchType {
                case exactId
                case exactName
                case builtInTarget
                case notFound
            }
        }

        struct ImportError {
            let message: String
            let affectedAssignments: [String]
        }

        struct ImportWarning {
            let message: String
            let affectedAssignments: [String]
        }

        struct ImportSummary {
            let totalAssignments: Int
            let importableAssignments: Int
            let matchedApplications: Int
            let matchedGroups: Int
            let conflicts: Int
            let duplicates: Int
        }
    }

    /// Parse and validate import data
    func validateImport(data: Data) async throws -> ImportValidation {
        isValidating = true
        defer { isValidating = false }

        // Decode the export container
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let container = try decoder.decode(AssignmentExportService.ExportContainer.self, from: data)

        // Ensure we have current data
        if applicationService.applications.isEmpty {
            _ = try? await applicationService.fetchApplications()
        }
        if groupService.groups.isEmpty {
            _ = try? await groupService.fetchGroups()
        }

        var validatedAssignments: [ImportValidation.ValidatedAssignment] = []
        let errors: [ImportValidation.ImportError] = []
        var warnings: [ImportValidation.ImportWarning] = []
        var matchedApps = Set<String>()
        var matchedGroups = Set<String>()
        var conflicts = 0
        var duplicates = 0

        // Process each assignment
        for exportedAssignment in container.assignments {
            var issues: [String] = []

            // Match application
            let appMatch = findApplicationMatch(
                exportedId: exportedAssignment.applicationId,
                exportedName: exportedAssignment.applicationName
            )

            if case .notFound = appMatch?.matchType {
                issues.append("Application not found: \(exportedAssignment.applicationName)")
            } else if let match = appMatch {
                matchedApps.insert(match.id)

                // Check for existing assignment
                if hasExistingAssignment(
                    applicationId: match.id,
                    groupId: exportedAssignment.groupId
                ) {
                    duplicates += 1
                    issues.append("Assignment already exists for this application and group")
                }
            }

            // Match group
            let groupMatch = findGroupMatch(
                exportedId: exportedAssignment.groupId,
                exportedName: exportedAssignment.groupName,
                targetType: exportedAssignment.targetType
            )

            if case .notFound = groupMatch?.matchType {
                issues.append("Group not found: \(exportedAssignment.groupName)")
            } else if let match = groupMatch {
                matchedGroups.insert(match.id)
            }

            // Validate intent
            if let intent = AppAssignment.AssignmentIntent(rawValue: exportedAssignment.intent) {
                // Check if intent is valid for the app type
                if let appMatch = appMatch,
                   let app = applicationService.applications.first(where: { $0.id == appMatch.id }) {
                    let targetType = AppAssignment.AssignmentTarget.TargetType(
                        rawValue: exportedAssignment.targetType
                    ) ?? .group

                    if !AssignmentIntentValidator.isIntentValid(
                        intent: intent,
                        appType: app.appType,
                        targetType: targetType
                    ) {
                        issues.append("Intent '\(intent.displayName)' is not valid for \(app.appType.displayName) apps")
                    }
                }
            } else {
                issues.append("Invalid intent: \(exportedAssignment.intent)")
            }

            let canImport = issues.isEmpty && appMatch != nil && groupMatch != nil

            let validated = ImportValidation.ValidatedAssignment(
                original: exportedAssignment,
                applicationMatch: appMatch,
                groupMatch: groupMatch,
                canImport: canImport,
                issues: issues
            )

            validatedAssignments.append(validated)
        }

        // Check for conflicts
        let conflictDetection = detectImportConflicts(assignments: validatedAssignments)
        conflicts = conflictDetection.count

        if conflicts > 0 {
            warnings.append(ImportValidation.ImportWarning(
                message: "\(conflicts) potential conflicts detected",
                affectedAssignments: conflictDetection.map { $0.applicationName }
            ))
        }

        let summary = ImportValidation.ImportSummary(
            totalAssignments: container.assignments.count,
            importableAssignments: validatedAssignments.filter { $0.canImport }.count,
            matchedApplications: matchedApps.count,
            matchedGroups: matchedGroups.count,
            conflicts: conflicts,
            duplicates: duplicates
        )

        let validation = ImportValidation(
            isValid: !validatedAssignments.filter { $0.canImport }.isEmpty,
            assignments: validatedAssignments,
            errors: errors,
            warnings: warnings,
            summary: summary
        )

        self.importValidation = validation
        return validation
    }

    /// Find matching application
    private func findApplicationMatch(
        exportedId: String,
        exportedName: String
    ) -> ImportValidation.ApplicationMatch? {
        // Try exact ID match
        if let app = applicationService.applications.first(where: { $0.id == exportedId }) {
            return ImportValidation.ApplicationMatch(
                id: app.id,
                name: app.displayName,
                matchType: .exactId
            )
        }

        // Try exact name match
        if let app = applicationService.applications.first(where: {
            $0.displayName.lowercased() == exportedName.lowercased()
        }) {
            return ImportValidation.ApplicationMatch(
                id: app.id,
                name: app.displayName,
                matchType: .exactName
            )
        }

        // Try fuzzy name match
        let fuzzyMatches = applicationService.applications.compactMap { app -> (app: Application, similarity: Double)? in
            let similarity = stringSimilarity(app.displayName, exportedName)
            return similarity > 0.7 ? (app, similarity) : nil
        }.sorted { $0.similarity > $1.similarity }

        if let bestMatch = fuzzyMatches.first {
            return ImportValidation.ApplicationMatch(
                id: bestMatch.app.id,
                name: bestMatch.app.displayName,
                matchType: .fuzzyName(similarity: bestMatch.similarity)
            )
        }

        return ImportValidation.ApplicationMatch(
            id: exportedId,
            name: exportedName,
            matchType: .notFound
        )
    }

    /// Find matching group
    private func findGroupMatch(
        exportedId: String,
        exportedName: String,
        targetType: String
    ) -> ImportValidation.GroupMatch? {
        // Check for built-in targets
        if targetType == "allDevices" || exportedId == DeviceGroup.allDevicesGroupID {
            return ImportValidation.GroupMatch(
                id: DeviceGroup.allDevicesGroupID,
                name: "All Devices",
                matchType: .builtInTarget
            )
        }

        if targetType == "allUsers" || exportedId == DeviceGroup.allUsersGroupID {
            return ImportValidation.GroupMatch(
                id: DeviceGroup.allUsersGroupID,
                name: "All Users",
                matchType: .builtInTarget
            )
        }

        // Try exact ID match
        if let group = groupService.groups.first(where: { $0.id == exportedId }) {
            return ImportValidation.GroupMatch(
                id: group.id,
                name: group.displayName,
                matchType: .exactId
            )
        }

        // Try exact name match
        if let group = groupService.groups.first(where: {
            $0.displayName.lowercased() == exportedName.lowercased()
        }) {
            return ImportValidation.GroupMatch(
                id: group.id,
                name: group.displayName,
                matchType: .exactName
            )
        }

        return ImportValidation.GroupMatch(
            id: exportedId,
            name: exportedName,
            matchType: .notFound
        )
    }

    /// Check if assignment already exists
    private func hasExistingAssignment(applicationId: String, groupId: String) -> Bool {
        guard let app = applicationService.applications.first(where: { $0.id == applicationId }) else {
            return false
        }

        return app.assignments?.contains { assignment in
            assignment.target.groupId == groupId ||
            (assignment.target.type == .allDevices && groupId == DeviceGroup.allDevicesGroupID) ||
            (assignment.target.type == .allUsers && groupId == DeviceGroup.allUsersGroupID)
        } ?? false
    }

    /// Detect conflicts in imported assignments
    private func detectImportConflicts(
        assignments: [ImportValidation.ValidatedAssignment]
    ) -> [AssignmentExportService.ExportableAssignment] {
        var conflicts: [AssignmentExportService.ExportableAssignment] = []
        var groupIntents: [String: [(app: String, intent: String)]] = [:]

        // Group assignments by group ID
        for assignment in assignments where assignment.canImport {
            let groupId = assignment.groupMatch?.id ?? assignment.original.groupId
            if groupIntents[groupId] == nil {
                groupIntents[groupId] = []
            }
            groupIntents[groupId]?.append((
                app: assignment.original.applicationName,
                intent: assignment.original.intent
            ))
        }

        // Check for conflicts
        for (_, intents) in groupIntents {
            let intentSet = Set(intents.map { $0.intent })

            // Check for Required vs Uninstall
            if intentSet.contains("required") && intentSet.contains("uninstall") {
                conflicts.append(contentsOf: assignments
                    .filter { assignment in
                        intents.contains { $0.app == assignment.original.applicationName }
                    }
                    .map { $0.original }
                )
            }
        }

        return conflicts
    }

    /// Calculate string similarity (Levenshtein distance based)
    private func stringSimilarity(_ str1: String, _ str2: String) -> Double {
        let s1 = str1.lowercased()
        let s2 = str2.lowercased()

        if s1 == s2 { return 1.0 }

        let len1 = s1.count
        let len2 = s2.count

        if len1 == 0 || len2 == 0 { return 0.0 }

        let maxLen = max(len1, len2)
        let distance = levenshteinDistance(s1, s2)

        return 1.0 - (Double(distance) / Double(maxLen))
    }

    /// Calculate Levenshtein distance
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count

        if m == 0 { return n }
        if n == 0 { return m }

        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 0...m {
            matrix[i][0] = i
        }
        for j in 0...n {
            matrix[0][j] = j
        }

        let s1Array = Array(s1)
        let s2Array = Array(s2)

        for i in 1...m {
            for j in 1...n {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[m][n]
    }

    /// Create pending assignments from validated import
    func createPendingAssignments(
        from validation: ImportValidation,
        onlyImportable: Bool = true
    ) -> [(appId: String, groupId: String, intent: AppAssignment.AssignmentIntent)] {
        var pendingAssignments: [(appId: String, groupId: String, intent: AppAssignment.AssignmentIntent)] = []

        for validated in validation.assignments {
            if onlyImportable && !validated.canImport {
                continue
            }

            guard let appMatch = validated.applicationMatch,
                  let groupMatch = validated.groupMatch,
                  let intent = AppAssignment.AssignmentIntent(rawValue: validated.original.intent) else {
                continue
            }

            pendingAssignments.append((
                appId: appMatch.id,
                groupId: groupMatch.id,
                intent: intent
            ))
        }

        return pendingAssignments
    }

    /// Execute the import
    func executeImport(validation: ImportValidation) async throws -> (successCount: Int, failedCount: Int) {
        let pendingAssignments = createPendingAssignments(from: validation)
        var successCount = 0
        var failedCount = 0

        for (appId, groupId, intent) in pendingAssignments {
            do {
                // Get the actual Application and DeviceGroup objects
                guard let app = applicationService.applications.first(where: { $0.id == appId }) else {
                    failedCount += 1
                    continue
                }

                // Convert AppAssignment.AssignmentIntent to Assignment.AssignmentIntent
                let assignmentIntent: Assignment.AssignmentIntent
                switch intent {
                case .available:
                    assignmentIntent = .available
                case .required:
                    assignmentIntent = .required
                case .uninstall:
                    assignmentIntent = .uninstall
                case .availableWithoutEnrollment:
                    assignmentIntent = .available // Map to available as there's no direct equivalent
                }

                // Handle special group IDs and get the actual group
                let groups: [DeviceGroup]
                if groupId == DeviceGroup.allDevicesGroupID {
                    // Create a pseudo group for all devices
                    let allDevicesGroup = DeviceGroup(
                        id: DeviceGroup.allDevicesGroupID,
                        displayName: "All Devices"
                    )
                    groups = [allDevicesGroup]
                } else if groupId == DeviceGroup.allUsersGroupID {
                    // Create a pseudo group for all users
                    let allUsersGroup = DeviceGroup(
                        id: DeviceGroup.allUsersGroupID,
                        displayName: "All Users"
                    )
                    groups = [allUsersGroup]
                } else if let group = groupService.groups.first(where: { $0.id == groupId }) {
                    groups = [group]
                } else {
                    failedCount += 1
                    continue
                }

                // Create a bulk assignment operation
                let operation = BulkAssignmentOperation(
                    applications: [app],
                    groups: groups,
                    intent: assignmentIntent
                )

                // Execute the assignment
                _ = try await AssignmentService.shared.performBulkAssignment(operation)

                successCount += 1
            } catch {
                failedCount += 1
                Logger.shared.error("Failed to import assignment for app \(appId): \(error)", category: .data)
            }
        }

        return (successCount: successCount, failedCount: failedCount)
    }
}