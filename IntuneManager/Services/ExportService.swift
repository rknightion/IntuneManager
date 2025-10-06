import Foundation
#if os(macOS)
import PDFKit
import AppKit
#endif

/// Service for exporting assignment summaries in various formats
@MainActor
final class ExportService {
    static let shared = ExportService()

    private init() {}

    // MARK: - Export Format

    enum ExportFormat: String, CaseIterable {
        case pdf = "PDF"
        case csv = "CSV"
        case json = "JSON"

        var fileExtension: String {
            switch self {
            case .pdf: return "pdf"
            case .csv: return "csv"
            case .json: return "json"
            }
        }

        var contentType: String {
            switch self {
            case .pdf: return "application/pdf"
            case .csv: return "text/csv"
            case .json: return "application/json"
            }
        }
    }

    // MARK: - Export Data Structure

    struct AssignmentSummaryExport: Codable {
        let exportDate: Date
        let totalAssignments: Int
        let applicationCount: Int
        let groupCount: Int
        let intent: String
        let applications: [ApplicationInfo]
        let groups: [GroupInfo]
        let settings: [GroupSettingInfo]
        let warnings: [WarningInfo]

        struct ApplicationInfo: Codable {
            let name: String
            let type: String
            let version: String?
            let publisher: String?
            let platforms: [String]
        }

        struct GroupInfo: Codable {
            let name: String
            let memberCount: Int?
        }

        struct GroupSettingInfo: Codable {
            let groupName: String
            let platformSettings: [String: String]
        }

        struct WarningInfo: Codable {
            let severity: String
            let message: String
        }
    }

    // MARK: - CSV Export

    func exportToCSV(
        applications: [Application],
        groups: [DeviceGroup],
        intent: Assignment.AssignmentIntent,
        groupSettings: [GroupAssignmentSettings]
    ) -> String {
        var csv = "Application,Type,Version,Publisher,Group,Members,Intent,Settings Summary\n"

        for app in applications {
            for group in groups {
                let settingInfo = groupSettings.first { $0.groupId == group.id }
                let settingsSummary = settingInfo.map { summarizeSettings($0.settings) } ?? "Default"

                let row = [
                    escapeCSV(app.displayName),
                    escapeCSV(app.appType.displayName),
                    escapeCSV(app.version ?? ""),
                    escapeCSV(app.publisher ?? ""),
                    escapeCSV(group.displayName),
                    "\(group.memberCount ?? 0)",
                    escapeCSV(intent.displayName),
                    escapeCSV(settingsSummary)
                ].joined(separator: ",")

                csv += row + "\n"
            }
        }

        return csv
    }

    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func summarizeSettings(_ settings: AppAssignmentSettings) -> String {
        var parts: [String] = []

        if let iosVpp = settings.iosVppSettings {
            parts.append("iOS VPP: \(iosVpp.useDeviceLicensing ? "Device" : "User") licensing")
        }
        if let macVpp = settings.macosVppSettings {
            parts.append("macOS VPP: \(macVpp.useDeviceLicensing ? "Device" : "User") licensing")
        }
        if let windows = settings.windowsSettings {
            parts.append("Windows: \(windows.notifications.rawValue) notifications")
        }

        return parts.isEmpty ? "Default" : parts.joined(separator: "; ")
    }

    // MARK: - JSON Export

    func exportToJSON(
        applications: [Application],
        groups: [DeviceGroup],
        intent: Assignment.AssignmentIntent,
        groupSettings: [GroupAssignmentSettings],
        warnings: [(severity: String, message: String)]
    ) throws -> Data {
        let export = AssignmentSummaryExport(
            exportDate: Date(),
            totalAssignments: applications.count * groups.count,
            applicationCount: applications.count,
            groupCount: groups.count,
            intent: intent.displayName,
            applications: applications.map { app in
                AssignmentSummaryExport.ApplicationInfo(
                    name: app.displayName,
                    type: app.appType.displayName,
                    version: app.version,
                    publisher: app.publisher,
                    platforms: app.supportedPlatforms.map { $0.displayName }
                )
            },
            groups: groups.map { group in
                AssignmentSummaryExport.GroupInfo(
                    name: group.displayName,
                    memberCount: group.memberCount
                )
            },
            settings: groupSettings.map { setting in
                AssignmentSummaryExport.GroupSettingInfo(
                    groupName: setting.groupName,
                    platformSettings: extractSettingsDict(setting.settings)
                )
            },
            warnings: warnings.map { warning in
                AssignmentSummaryExport.WarningInfo(
                    severity: warning.severity,
                    message: warning.message
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(export)
    }

    private func extractSettingsDict(_ settings: AppAssignmentSettings) -> [String: String] {
        var dict: [String: String] = [:]

        if let iosVpp = settings.iosVppSettings {
            dict["iOS_VPP_DeviceLicensing"] = "\(iosVpp.useDeviceLicensing)"
            dict["iOS_VPP_UninstallOnRemoval"] = "\(iosVpp.uninstallOnDeviceRemoval)"
        }
        if let macVpp = settings.macosVppSettings {
            dict["macOS_VPP_DeviceLicensing"] = "\(macVpp.useDeviceLicensing)"
        }
        if let windows = settings.windowsSettings {
            dict["Windows_Notifications"] = windows.notifications.rawValue
        }

        return dict
    }

    // MARK: - PDF Export (macOS only)

    #if os(macOS)
    func exportToPDF(
        applications: [Application],
        groups: [DeviceGroup],
        intent: Assignment.AssignmentIntent,
        groupSettings: [GroupAssignmentSettings],
        warnings: [(severity: String, message: String)]
    ) -> PDFDocument? {
        let pdfDocument = PDFDocument()

        // Create PDF pages
        let pageSize = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        var currentY: CGFloat = 750

        let page = PDFPage()
        let context = NSGraphicsContext.current

        // Use attributed strings to build PDF content
        var pdfContent = NSMutableAttributedString()

        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        pdfContent.append(NSAttributedString(string: "Assignment Summary Report\n\n", attributes: titleAttrs))

        // Summary section
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.black
        ]
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.black
        ]

        pdfContent.append(NSAttributedString(string: "Summary\n", attributes: headerAttrs))
        pdfContent.append(NSAttributedString(
            string: "Total Assignments: \(applications.count * groups.count)\n",
            attributes: bodyAttrs
        ))
        pdfContent.append(NSAttributedString(
            string: "Intent: \(intent.displayName)\n",
            attributes: bodyAttrs
        ))
        pdfContent.append(NSAttributedString(
            string: "Applications: \(applications.count)\n",
            attributes: bodyAttrs
        ))
        pdfContent.append(NSAttributedString(
            string: "Groups: \(groups.count)\n",
            attributes: bodyAttrs
        ))
        pdfContent.append(NSAttributedString(
            string: "Export Date: \(Date().formatted())\n\n",
            attributes: bodyAttrs
        ))

        // Applications section
        pdfContent.append(NSAttributedString(string: "Applications\n", attributes: headerAttrs))
        for app in applications {
            pdfContent.append(NSAttributedString(
                string: "• \(app.displayName) (\(app.appType.displayName))\n",
                attributes: bodyAttrs
            ))
        }
        pdfContent.append(NSAttributedString(string: "\n", attributes: bodyAttrs))

        // Groups section
        pdfContent.append(NSAttributedString(string: "Groups\n", attributes: headerAttrs))
        for group in groups {
            let memberInfo = group.memberCount.map { " (\($0) members)" } ?? ""
            pdfContent.append(NSAttributedString(
                string: "• \(group.displayName)\(memberInfo)\n",
                attributes: bodyAttrs
            ))
        }
        pdfContent.append(NSAttributedString(string: "\n", attributes: bodyAttrs))

        // Warnings section
        if !warnings.isEmpty {
            pdfContent.append(NSAttributedString(string: "Warnings\n", attributes: headerAttrs))
            for warning in warnings {
                pdfContent.append(NSAttributedString(
                    string: "[\(warning.severity)] \(warning.message)\n",
                    attributes: bodyAttrs
                ))
            }
        }

        // Create PDF from attributed string
        let data = NSMutableData()
        let consumer = CGDataConsumer(data: data as CFMutableData)!
        var mediaBox = pageSize
        let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)!

        pdfContext.beginPage(mediaBox: &mediaBox)

        // Draw the attributed string
        let framePath = NSBezierPath(rect: CGRect(x: 50, y: 50, width: 512, height: 692))
        let textContainer = NSTextContainer(containerSize: CGSize(width: 512, height: 692))
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: pdfContent)

        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        pdfContext.saveGState()
        pdfContext.translateBy(x: 50, y: 50)

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)

        pdfContext.restoreGState()
        pdfContext.endPage()
        pdfContext.closePDF()

        return PDFDocument(data: data as Data)
    }
    #endif
}
