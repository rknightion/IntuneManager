import Foundation
import UniformTypeIdentifiers

final class AssignmentExportService {
    static let shared = AssignmentExportService()

    private init() {}

    /// Exportable representation of assignments
    struct ExportableAssignment: Codable {
        let applicationId: String
        let applicationName: String
        let applicationType: String
        let groupId: String
        let groupName: String
        let targetType: String
        let intent: String
        let settings: AssignmentSettings?
        let filter: AssignmentFilter?
        let createdDate: Date?
        let createdBy: String?

        struct AssignmentSettings: Codable {
            let notificationEnabled: Bool?
            let uninstallOnDeviceRemoval: Bool?
            let vpnConfigurationId: String?
        }

        struct AssignmentFilter: Codable {
            let filterId: String?
            let filterType: String?
            let filterExpression: String?
        }
    }

    /// Export format container
    struct ExportContainer: Codable {
        let version: String
        let exportDate: Date
        let tenantId: String?
        let exportedBy: String?
        let assignments: [ExportableAssignment]
        let summary: ExportSummary

        struct ExportSummary: Codable {
            let totalAssignments: Int
            let uniqueApplications: Int
            let uniqueGroups: Int
            let intentBreakdown: [String: Int]
        }
    }

    /// Export assignments to JSON format
    func exportAssignments(
        applications: [Application],
        selectedApplications: Set<String>? = nil,
        selectedGroups: Set<String>? = nil
    ) throws -> Data {
        var exportableAssignments: [ExportableAssignment] = []
        var intentCounts: [String: Int] = [:]

        // Process each application
        for app in applications {
            // Skip if not in selected applications (if filter is provided)
            if let selected = selectedApplications, !selected.contains(app.id) {
                continue
            }

            // Process assignments for this application
            for assignment in app.assignments ?? [] {
                // Skip if not in selected groups (if filter is provided)
                if let selected = selectedGroups,
                   let groupId = assignment.target.groupId,
                   !selected.contains(groupId) {
                    continue
                }

                let exportable = ExportableAssignment(
                    applicationId: app.id,
                    applicationName: app.displayName,
                    applicationType: app.appType.rawValue,
                    groupId: assignment.target.groupId ?? assignment.target.type.rawValue,
                    groupName: assignment.target.groupName ?? assignment.target.type.displayName,
                    targetType: assignment.target.type.rawValue,
                    intent: assignment.intent.rawValue,
                    settings: nil, // Could be expanded to include actual settings
                    filter: nil,   // Could be expanded to include filters
                    createdDate: nil,
                    createdBy: nil
                )

                exportableAssignments.append(exportable)

                // Count intents for summary
                intentCounts[assignment.intent.rawValue, default: 0] += 1
            }
        }

        // Create export container
        let container = ExportContainer(
            version: "1.0",
            exportDate: Date(),
            tenantId: nil, // Could be populated from auth context
            exportedBy: nil, // Could be populated from auth context
            assignments: exportableAssignments,
            summary: ExportContainer.ExportSummary(
                totalAssignments: exportableAssignments.count,
                uniqueApplications: Set(exportableAssignments.map { $0.applicationId }).count,
                uniqueGroups: Set(exportableAssignments.map { $0.groupId }).count,
                intentBreakdown: intentCounts
            )
        )

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(container)
    }

    /// Generate filename for export
    func generateExportFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = formatter.string(from: Date())
        return "intune-assignments-\(dateString).json"
    }

    /// Export assignments to CSV format
    func exportAssignmentsAsCSV(
        applications: [Application],
        selectedApplications: Set<String>? = nil,
        selectedGroups: Set<String>? = nil
    ) -> String {
        var csvContent = "Application ID,Application Name,Application Type,Group ID,Group Name,Target Type,Intent\n"

        for app in applications {
            // Skip if not in selected applications (if filter is provided)
            if let selected = selectedApplications, !selected.contains(app.id) {
                continue
            }

            for assignment in app.assignments ?? [] {
                // Skip if not in selected groups (if filter is provided)
                if let selected = selectedGroups,
                   let groupId = assignment.target.groupId,
                   !selected.contains(groupId) {
                    continue
                }

                let row = [
                    app.id,
                    app.displayName.replacingOccurrences(of: ",", with: ";"),
                    app.appType.rawValue,
                    assignment.target.groupId ?? assignment.target.type.rawValue,
                    (assignment.target.groupName ?? assignment.target.type.displayName)
                        .replacingOccurrences(of: ",", with: ";"),
                    assignment.target.type.rawValue,
                    assignment.intent.rawValue
                ].joined(separator: ",")

                csvContent += row + "\n"
            }
        }

        return csvContent
    }

    /// Generate CSV filename
    func generateCSVFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let dateString = formatter.string(from: Date())
        return "intune-assignments-\(dateString).csv"
    }
}

// MARK: - UTType Extensions for Export

extension UTType {
    static let intuneAssignmentExport = UTType(exportedAs: "com.intunemanager.assignment-export")
}