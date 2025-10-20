import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
import PDFKit
#endif

struct ReviewAssignmentView: View {
    @ObservedObject var viewModel: BulkAssignmentViewModel
    @Binding var currentStep: BulkAssignmentView.AssignmentStep
    @State private var isValidating = false
    @State private var assignmentFilters: [AssignmentFilter] = []
    @State private var isLoadingFilters = false
    @State private var showExportMenu = false
    @State private var exportFormat: ExportService.ExportFormat = .csv
    @State private var exportData: Data?
    @State private var showFileExporter = false

    var summary: BulkAssignmentViewModel.AssignmentSummary {
        viewModel.getAssignmentSummary()
    }

    /// Extract unique filter IDs from all group assignment settings
    var uniqueFilterIds: Set<String> {
        Set(
            viewModel.groupAssignmentSettings
                .compactMap { $0.assignmentFilterId }
                .filter { !$0.isEmpty }
        )
    }

    // MARK: - Enhanced Validation Warnings

    struct ValidationWarning: Identifiable {
        let id = UUID()
        let severity: Severity
        let message: String
        let action: ValidationAction?

        enum Severity: String {
            case error = "Error"
            case warning = "Warning"
            case info = "Info"

            var icon: String {
                switch self {
                case .error: return "xmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .info: return "info.circle.fill"
                }
            }

            var color: Color {
                switch self {
                case .error: return .red
                case .warning: return .orange
                case .info: return .blue
                }
            }
        }

        enum ValidationAction {
            case navigateToSettings
            case navigateToGroups
            case navigateToApps
            case showHelp(url: String)
        }
    }

    var validationWarnings: [ValidationWarning] {
        var warnings: [ValidationWarning] = []

        // Platform compatibility checks
        let platformSets = viewModel.selectedApplications.map { $0.supportedPlatforms }
        let commonPlatforms = platformSets.first.map { first in
            platformSets.dropFirst().reduce(first) { $0.intersection($1) }
        } ?? []

        if commonPlatforms.isEmpty && !viewModel.selectedApplications.isEmpty {
            warnings.append(ValidationWarning(
                severity: .warning,
                message: "Selected apps have no common platform support. Assignments may fail for incompatible devices.",
                action: .navigateToApps
            ))
        } else if !commonPlatforms.isEmpty {
            let unsupportedPlatforms = Application.DevicePlatform.allCases.filter {
                $0 != .unknown && !commonPlatforms.contains($0)
            }
            if !unsupportedPlatforms.isEmpty {
                let platformNames = unsupportedPlatforms.map { $0.displayName }.joined(separator: ", ")
                warnings.append(ValidationWarning(
                    severity: .info,
                    message: "Selected apps do not support: \(platformNames)",
                    action: nil
                ))
            }
        }

        // VPP and Windows compatibility
        let hasVppApps = viewModel.selectedApplications.contains {
            $0.appType == .iosVppApp || $0.appType == .macOSVppApp
        }
        let hasWindowsOnlyApps = viewModel.selectedApplications.contains { app in
            let platforms = app.supportedPlatforms
            return platforms.count == 1 && platforms.contains(.windows)
        }

        if hasVppApps && hasWindowsOnlyApps {
            warnings.append(ValidationWarning(
                severity: .warning,
                message: "Mixing VPP apps with Windows-only apps. These will fail on incompatible devices.",
                action: .navigateToApps
            ))
        }

        // VPN configuration validation
        let settingsWithVPN = viewModel.groupAssignmentSettings.filter { groupSettings in
            if let iosVpp = groupSettings.settings.iosVppSettings {
                return iosVpp.vpnConfigurationId != nil
            } else if let iosLob = groupSettings.settings.iosLobSettings {
                return iosLob.vpnConfigurationId != nil
            }
            return false
        }

        if !settingsWithVPN.isEmpty {
            warnings.append(ValidationWarning(
                severity: .warning,
                message: "\(settingsWithVPN.count) group(s) have VPN configured. Ensure VPN profiles exist before deployment.",
                action: .navigateToSettings
            ))
        }

        // Assignment filter validation
        let settingsWithFilters = viewModel.groupAssignmentSettings.filter { $0.assignmentFilterId != nil }

        if !settingsWithFilters.isEmpty {
            warnings.append(ValidationWarning(
                severity: .info,
                message: "\(settingsWithFilters.count) group(s) use assignment filters. Verify filters are configured correctly.",
                action: .navigateToSettings
            ))
        }

        // Permission check (basic - could be enhanced with actual Graph API permission check)
        if viewModel.totalNewAssignments > 100 {
            warnings.append(ValidationWarning(
                severity: .info,
                message: "Large bulk operation (\(viewModel.totalNewAssignments) assignments). Ensure adequate Graph API permissions.",
                action: .showHelp(url: "https://learn.microsoft.com/en-us/graph/permissions-reference")
            ))
        }

        // Empty groups warning
        let emptyGroups = viewModel.selectedGroups.filter { group in
            group.memberCount == 0 && !group.isBuiltInAssignmentTarget
        }

        if !emptyGroups.isEmpty {
            let groupNames = emptyGroups.prefix(3).map { $0.displayName }.joined(separator: ", ")
            let suffix = emptyGroups.count > 3 ? " and \(emptyGroups.count - 3) more" : ""
            warnings.append(ValidationWarning(
                severity: .warning,
                message: "Empty groups selected: \(groupNames)\(suffix). No devices will receive these apps.",
                action: .navigateToGroups
            ))
        }

        return warnings
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Validation Progress Indicator
                if isValidating {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Validating assignments...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                // Enhanced Validation Warnings
                if !validationWarnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(validationWarnings) { warning in
                            ValidationWarningCard(
                                warning: warning,
                                onAction: { action in
                                    handleWarningAction(action)
                                }
                            )
                        }
                    }
                }

                // Summary Card
                SummaryCard(summary: summary, targetPlatform: viewModel.targetPlatform)
                
                // Selected Applications
                SectionView(title: "Selected Applications (\(summary.applicationCount))") {
                    ForEach(Array(viewModel.selectedApplications), id: \.id) { app in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(app.displayName)
                                    .lineLimit(1)
                                Spacer()
                                Text("→ \(summary.groupCount) groups")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 8) {
                                Label(app.appType.displayName, systemImage: app.appType.icon)
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                // Show supported platforms
                                if !app.supportedPlatforms.isEmpty {
                                    HStack(spacing: 2) {
                                        ForEach(Array(app.supportedPlatforms.sorted { $0.rawValue < $1.rawValue }), id: \.self) { platform in
                                            Image(systemName: platform.icon)
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }

                                if let version = app.version, !version.isEmpty {
                                    Text("v\(version)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                if let publisher = app.publisher, !publisher.isEmpty {
                                    Text(publisher)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Selected Groups
                SectionView(title: "Selected Groups (\(summary.groupCount))") {
                    ForEach(Array(viewModel.selectedGroups), id: \.id) { group in
                        HStack {
                            Text(group.displayName)
                                .lineLimit(1)
                            Spacer()
                            Text("← \(summary.applicationCount) apps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // Settings Preview Per Group
                if !viewModel.groupAssignmentSettings.isEmpty {
                    SectionView(title: "Assignment Settings by Group") {
                        ForEach(viewModel.groupAssignmentSettings) { groupSettings in
                            SettingsPreviewCard(
                                groupSettings: groupSettings,
                                allGroupSettings: viewModel.groupAssignmentSettings,
                                onEditSettings: {
                                    currentStep = .configureSettings
                                }
                            )
                        }
                    }
                }

                // Filter Preview Section
                if !uniqueFilterIds.isEmpty {
                    SectionView(title: "Assignment Filters (\(uniqueFilterIds.count))") {
                        FilterPreviewSection(
                            filterIds: uniqueFilterIds,
                            groupSettings: viewModel.groupAssignmentSettings,
                            assignmentFilters: $assignmentFilters,
                            isLoadingFilters: $isLoadingFilters
                        )
                    }
                }

                // Assignment Matrix View
                if !viewModel.selectedApplications.isEmpty && !viewModel.selectedGroups.isEmpty {
                    SectionView(title: "Assignment Matrix") {
                        AssignmentMatrixView(
                            applications: Array(viewModel.selectedApplications),
                            groups: Array(viewModel.selectedGroups),
                            intent: viewModel.assignmentIntent
                        )
                    }
                }
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Button {
                        exportFormat = .csv
                        exportAssignment(format: .csv)
                    } label: {
                        Label("Export as CSV", systemImage: "doc.text")
                    }

                    Button {
                        exportFormat = .json
                        exportAssignment(format: .json)
                    } label: {
                        Label("Export as JSON", systemImage: "doc.badge.gearshape")
                    }

                    #if os(macOS)
                    Button {
                        exportFormat = .pdf
                        exportAssignment(format: .pdf)
                    } label: {
                        Label("Export as PDF", systemImage: "doc.richtext")
                    }
                    #endif
                } label: {
                    Label("Export Summary", systemImage: "square.and.arrow.up")
                }
            }
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: ExportDocument(data: exportData ?? Data()),
            contentType: .data,
            defaultFilename: "assignment-summary-\(Date().formatted(.iso8601.year().month().day())).\(exportFormat.fileExtension)"
        ) { result in
            switch result {
            case .success(let url):
                Logger.shared.info("Exported assignment summary to: \(url.path)", category: .app)
            case .failure(let error):
                Logger.shared.error("Failed to export assignment summary: \(error.localizedDescription)", category: .app)
            }
        }
    }

    // MARK: - Export Functions

    private func exportAssignment(format: ExportService.ExportFormat) {
        let service = ExportService.shared

        do {
            let warnings = validationWarnings.map { (severity: $0.severity.rawValue, message: $0.message) }

            switch format {
            case .csv:
                let csvString = service.exportToCSV(
                    applications: Array(viewModel.selectedApplications),
                    groups: Array(viewModel.selectedGroups),
                    intent: viewModel.assignmentIntent,
                    groupSettings: viewModel.groupAssignmentSettings
                )
                exportData = csvString.data(using: .utf8)
                showFileExporter = true

            case .json:
                exportData = try service.exportToJSON(
                    applications: Array(viewModel.selectedApplications),
                    groups: Array(viewModel.selectedGroups),
                    intent: viewModel.assignmentIntent,
                    groupSettings: viewModel.groupAssignmentSettings,
                    warnings: warnings
                )
                showFileExporter = true

            #if os(macOS)
            case .pdf:
                if let pdfDoc = service.exportToPDF(
                    applications: Array(viewModel.selectedApplications),
                    groups: Array(viewModel.selectedGroups),
                    intent: viewModel.assignmentIntent,
                    groupSettings: viewModel.groupAssignmentSettings,
                    warnings: warnings
                ) {
                    exportData = pdfDoc.dataRepresentation()
                    showFileExporter = true
                }
            #endif
            }
        } catch {
            Logger.shared.error("Failed to generate export data: \(error.localizedDescription)", category: .app)
        }
    }

    // MARK: - Warning Action Handler

    private func handleWarningAction(_ action: ValidationWarning.ValidationAction) {
        switch action {
        case .navigateToSettings:
            currentStep = .configureSettings
        case .navigateToGroups:
            currentStep = .selectGroups
        case .navigateToApps:
            currentStep = .selectApps
        case .showHelp(let url):
            if let url = URL(string: url) {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

struct SummaryCard: View {
    let summary: BulkAssignmentViewModel.AssignmentSummary
    let targetPlatform: Application.DevicePlatform?

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Assignments")
                        .font(.headline)
                    Text("\(summary.totalAssignments)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                Spacer()
                Image(systemName: summary.intent.icon)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Estimated Time: \(summary.estimatedTime)", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Label(summary.intent.displayName, systemImage: summary.intent.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let platform = targetPlatform {
                    Label("Target Platform: \(platform.displayName)", systemImage: platform.icon)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(12)
    }
}

struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

// MARK: - Settings Preview Card
struct SettingsPreviewCard: View {
    let groupSettings: GroupAssignmentSettings
    let allGroupSettings: [GroupAssignmentSettings]
    let onEditSettings: () -> Void

    @State private var isExpanded = false

    // Check if this group's settings differ from others
    private var hasUnusualSettings: Bool {
        guard allGroupSettings.count > 1 else { return false }

        // Simple heuristic: if this is the only group with certain settings,
        // it's "unusual" compared to the majority
        let otherSettings = allGroupSettings.filter { $0.id != groupSettings.id }

        // For now, we'll just check if settings objects differ
        // A more sophisticated implementation would compare specific fields
        return otherSettings.contains { other in
            settingsSummary(for: groupSettings.settings) != settingsSummary(for: other.settings)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(groupSettings.groupName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if hasUnusualSettings {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Spacer()

                Text(groupSettings.settings.intent.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(intentColor(groupSettings.settings.intent).opacity(0.2))
                    .foregroundColor(intentColor(groupSettings.settings.intent))
                    .cornerRadius(4)

                Button(action: onEditSettings) {
                    Label("Edit", systemImage: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    isExpanded.toggle()
                }
            }

            // Expanded Settings Details
            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    // Assignment Mode
                    SimpleSettingRow(
                        label: "Assignment Mode",
                        value: groupSettings.assignmentMode.displayName,
                        icon: groupSettings.assignmentMode.icon,
                        isDifferent: checkIfDifferent(\.assignmentMode)
                    )

                    // Platform-specific settings
                    settingsContent(for: groupSettings.settings)
                }
                .font(.caption)
                .padding(.leading, 20)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helper Functions

    @ViewBuilder
    private func settingsContent(for settings: AppAssignmentSettings) -> some View {
        if let iosVppSettings = settings.iosVppSettings {
            iosVppSettingsView(iosVppSettings)
        } else if let iosLobSettings = settings.iosLobSettings {
            iosLobSettingsView(iosLobSettings)
        } else if let macosVppSettings = settings.macosVppSettings {
            macosVppSettingsView(macosVppSettings)
        } else if let macosLobSettings = settings.macosLobSettings {
            macosLobSettingsView(macosLobSettings)
        } else if let windowsSettings = settings.windowsSettings {
            windowsSettingsView(windowsSettings)
        } else if let androidSettings = settings.androidSettings {
            androidSettingsView(androidSettings)
        }
    }

    // iOS VPP Settings
    @ViewBuilder
    private func iosVppSettingsView(_ settings: IOSVppAppAssignmentSettings) -> some View {
        SimpleSettingRow(label: "Device Licensing", value: settings.useDeviceLicensing ? "Yes" : "No")
        if settings.vpnConfigurationId != nil {
            SimpleSettingRow(label: "VPN", value: "Configured", icon: "network")
        }
        SimpleSettingRow(label: "Uninstall on Removal", value: settings.uninstallOnDeviceRemoval ? "Yes" : "No")
        SimpleSettingRow(label: "Removable", value: settings.isRemovable ? "Yes" : "No")
        SimpleSettingRow(label: "Prevent Backup", value: settings.preventManagedAppBackup ? "Yes" : "No")
        SimpleSettingRow(label: "Prevent Auto Update", value: settings.preventAutoAppUpdate ? "Yes" : "No")
    }

    // iOS LOB Settings
    @ViewBuilder
    private func iosLobSettingsView(_ settings: IOSLobAppAssignmentSettings) -> some View {
        if settings.vpnConfigurationId != nil {
            SimpleSettingRow(label: "VPN", value: "Configured", icon: "network")
        }
        SimpleSettingRow(label: "Uninstall on Removal", value: settings.uninstallOnDeviceRemoval ? "Yes" : "No")
        SimpleSettingRow(label: "Prevent Backup", value: settings.preventManagedAppBackup ? "Yes" : "No")
    }

    // macOS VPP Settings
    @ViewBuilder
    private func macosVppSettingsView(_ settings: MacOSVppAppAssignmentSettings) -> some View {
        SimpleSettingRow(label: "Device Licensing", value: settings.useDeviceLicensing ? "Yes" : "No")
        SimpleSettingRow(label: "Uninstall on Removal", value: settings.uninstallOnDeviceRemoval ? "Yes" : "No")
    }

    // macOS DMG Settings
    @ViewBuilder
    private func macosLobSettingsView(_ settings: MacOSLobAppAssignmentSettings) -> some View {
        SimpleSettingRow(label: "Uninstall on Device Removal", value: settings.uninstallOnDeviceRemoval ? "Yes" : "No")
    }

    // Windows Settings
    @ViewBuilder
    private func windowsSettingsView(_ settings: WindowsAppAssignmentSettings) -> some View {
        SimpleSettingRow(label: "Notifications", value: settings.notifications.displayName)
        SimpleSettingRow(label: "Delivery Priority", value: settings.deliveryOptimizationPriority.displayName)

        if let restart = settings.restartSettings {
            SimpleSettingRow(label: "Grace Period", value: "\(restart.gracePeriodInMinutes) min")
        }

        if let installTime = settings.installTimeSettings {
            SimpleSettingRow(label: "Use Local Time", value: installTime.useLocalTime ? "Yes" : "No")
        }
    }

    // Android Settings
    @ViewBuilder
    private func androidSettingsView(_ settings: AndroidManagedStoreAppAssignmentSettings) -> some View {
        SimpleSettingRow(label: "Auto Update Mode", value: settings.autoUpdateMode.displayName)

        if let trackIds = settings.androidManagedStoreAppTrackIds, !trackIds.isEmpty {
            SimpleSettingRow(
                label: "Track IDs",
                value: "\(trackIds.count) configured",
                icon: "tag.fill"
            )
        }
    }

    // Check if a specific keypath differs from other groups
    private func checkIfDifferent<T: Equatable>(_ keyPath: KeyPath<GroupAssignmentSettings, T>) -> Bool {
        let thisValue = groupSettings[keyPath: keyPath]
        return allGroupSettings.contains { $0.id != groupSettings.id && $0[keyPath: keyPath] != thisValue }
    }

    // Generate a summary string for settings comparison
    private func settingsSummary(for settings: AppAssignmentSettings) -> String {
        var summary = settings.intent.rawValue

        if let iosVpp = settings.iosVppSettings {
            summary += "-iosVpp-\(iosVpp.useDeviceLicensing)-\(iosVpp.isRemovable)"
        } else if let iosLob = settings.iosLobSettings {
            summary += "-iosLob-\(iosLob.uninstallOnDeviceRemoval)"
        } else if let macosVpp = settings.macosVppSettings {
            summary += "-macosVpp-\(macosVpp.useDeviceLicensing)"
        } else if let macosLob = settings.macosLobSettings {
            summary += "-macosLob-\(macosLob.uninstallOnDeviceRemoval)"
        } else if let windows = settings.windowsSettings {
            summary += "-windows-\(windows.notifications.rawValue)"
        } else if let android = settings.androidSettings {
            summary += "-android-\(android.autoUpdateMode.rawValue)"
        }

        return summary
    }

    private func intentColor(_ intent: Assignment.AssignmentIntent) -> Color {
        switch intent {
        case .required:
            return .red
        case .available:
            return .blue
        case .uninstall:
            return .orange
        case .availableWithoutEnrollment:
            return .purple
        }
    }
}

// MARK: - Assignment Matrix View
struct AssignmentMatrixView: View {
    let applications: [Application]
    let groups: [DeviceGroup]
    let intent: Assignment.AssignmentIntent

    @State private var sortedBy: MatrixSortOption = .appName
    @State private var filterText = ""
    @State private var showOnlyAssigned = false

    enum MatrixSortOption: String, CaseIterable {
        case appName = "App Name"
        case appType = "App Type"
        case groupName = "Group Name"

        var icon: String {
            switch self {
            case .appName: return "textformat.abc"
            case .appType: return "app.badge"
            case .groupName: return "person.3"
            }
        }
    }

    private var sortedApplications: [Application] {
        var sorted = applications
        switch sortedBy {
        case .appName:
            sorted = sorted.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        case .appType:
            sorted = sorted.sorted { $0.appType.displayName < $1.appType.displayName }
        case .groupName:
            break // No change for apps when sorting by group
        }

        if !filterText.isEmpty {
            sorted = sorted.filter { $0.displayName.localizedCaseInsensitiveContains(filterText) }
        }

        return sorted
    }

    private var sortedGroups: [DeviceGroup] {
        var sorted = groups
        switch sortedBy {
        case .groupName:
            sorted = sorted.sorted { $0.displayName.lowercased() < $1.displayName.lowercased() }
        case .appName, .appType:
            break // No change for groups when sorting by app
        }

        if !filterText.isEmpty {
            sorted = sorted.filter { $0.displayName.localizedCaseInsensitiveContains(filterText) }
        }

        return sorted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Controls
            HStack {
                // Filter
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField("Filter...", text: $filterText)
                        .textFieldStyle(.plain)
                        .font(.caption)
                }
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .frame(maxWidth: 200)

                // Sort
                Picker("Sort", selection: $sortedBy) {
                    ForEach(MatrixSortOption.allCases, id: \.self) { option in
                        Label(option.rawValue, systemImage: option.icon)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)

                Spacer()

                Text("\(sortedApplications.count) × \(sortedGroups.count) = \(sortedApplications.count * sortedGroups.count) assignments")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Matrix
            #if os(macOS)
            matrixTableView
            #else
            matrixScrollView
            #endif
        }
    }

    // MARK: - macOS Table View
    #if os(macOS)
    private var matrixTableView: some View {
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row
                HStack(spacing: 0) {
                    // Top-left corner cell
                    Text("Apps \\ Groups")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 200, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))

                    // Group headers
                    ForEach(sortedGroups) { group in
                        VStack(alignment: .center, spacing: 2) {
                            Text(group.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)

                            if let memberCount = group.memberCount {
                                Text("\(memberCount) members")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 100, alignment: .center)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                    }
                }

                // App rows
                ForEach(sortedApplications) { app in
                    HStack(spacing: 0) {
                        // App name cell
                        HStack(spacing: 8) {
                            Image(systemName: app.appType.icon)
                                .foregroundColor(.accentColor)
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.displayName)
                                    .font(.caption)
                                    .lineLimit(1)

                                Text(app.appType.displayName)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 200, alignment: .leading)
                        .padding(8)
                        .background(Color.gray.opacity(0.05))

                        // Assignment cells
                        ForEach(sortedGroups) { group in
                            MatrixCell(intent: intent)
                                .frame(width: 100)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 400)
    }
    #endif

    // MARK: - iOS Scroll View
    private var matrixScrollView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        // Top-left corner
                        Text("Apps")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 150, alignment: .leading)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))

                        // Group headers
                        ForEach(sortedGroups) { group in
                            Text(group.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .frame(width: 80)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                        }
                    }

                    // App rows
                    ForEach(sortedApplications) { app in
                        HStack(spacing: 0) {
                            // App cell
                            HStack(spacing: 4) {
                                Image(systemName: app.appType.icon)
                                    .font(.caption2)
                                Text(app.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(width: 150, alignment: .leading)
                            .padding(8)
                            .background(Color.gray.opacity(0.05))

                            // Assignment cells
                            ForEach(sortedGroups) { group in
                                MatrixCell(intent: intent)
                                    .frame(width: 80)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

// MARK: - Matrix Cell
struct MatrixCell: View {
    let intent: Assignment.AssignmentIntent

    private var intentColor: Color {
        switch intent {
        case .required:
            return .red
        case .available:
            return .blue
        case .uninstall:
            return .orange
        case .availableWithoutEnrollment:
            return .purple
        }
    }

    var body: some View {
        VStack {
            Image(systemName: intent.icon)
                .font(.caption)
                .foregroundColor(intentColor)

            Text(intentAbbreviation)
                .font(.caption2)
                .foregroundColor(intentColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(intentColor.opacity(0.1))
    }

    private var intentAbbreviation: String {
        switch intent {
        case .required:
            return "Req"
        case .available:
            return "Avail"
        case .uninstall:
            return "Uninst"
        case .availableWithoutEnrollment:
            return "Avail*"
        }
    }
}

// MARK: - Validation Warning Card
struct ValidationWarningCard: View {
    let warning: ReviewAssignmentView.ValidationWarning
    let onAction: (ReviewAssignmentView.ValidationWarning.ValidationAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: warning.severity.icon)
                .font(.title3)
                .foregroundColor(warning.severity.color)
                .frame(width: 24)

            // Message
            VStack(alignment: .leading, spacing: 4) {
                Text(warning.message)
                    .font(.caption)
                    .foregroundColor(.primary)

                // Action button if available
                if let action = warning.action {
                    Button(action: {
                        onAction(action)
                    }) {
                        HStack(spacing: 4) {
                            Text(actionButtonLabel(for: action))
                                .font(.caption2)
                            Image(systemName: "arrow.right")
                                .font(.caption2)
                        }
                        .foregroundColor(warning.severity.color)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(warning.severity.color.opacity(0.1))
        .cornerRadius(8)
    }

    private func actionButtonLabel(for action: ReviewAssignmentView.ValidationWarning.ValidationAction) -> String {
        switch action {
        case .navigateToSettings:
            return "Go to Settings"
        case .navigateToGroups:
            return "Review Groups"
        case .navigateToApps:
            return "Review Apps"
        case .showHelp:
            return "Learn More"
        }
    }
}

// MARK: - Simple Setting Row Component
struct SimpleSettingRow: View {
    let label: String
    let value: String
    var icon: String? = nil
    var isDifferent: Bool = false

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }

            Text(label)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .fontWeight(isDifferent ? .semibold : .regular)
                .foregroundColor(isDifferent ? .orange : .primary)

            if isDifferent {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }
}

// MARK: - Filter Preview Section
struct FilterPreviewSection: View {
    let filterIds: Set<String>
    let groupSettings: [GroupAssignmentSettings]
    @Binding var assignmentFilters: [AssignmentFilter]
    @Binding var isLoadingFilters: Bool
    @ObservedObject private var filterService = AssignmentFilterService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isLoadingFilters {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading filter details...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if assignmentFilters.isEmpty {
                // No filters loaded yet, show minimal info
                ForEach(Array(filterIds), id: \.self) { filterId in
                    FilterSummaryCard(
                        filterId: filterId,
                        filter: nil,
                        groupSettings: groupSettings
                    )
                }
            } else {
                ForEach(assignmentFilters) { filter in
                    FilterSummaryCard(
                        filterId: filter.id,
                        filter: filter,
                        groupSettings: groupSettings
                    )
                }
            }
        }
        .task {
            await loadFilterDetails()
        }
    }

    /// Fetch filter details from Graph API
    private func loadFilterDetails() async {
        guard !isLoadingFilters && assignmentFilters.isEmpty else { return }

        isLoadingFilters = true
        defer { isLoadingFilters = false }

        let filters = await filterService.getFilters()
        let relevantFilters = filters.filter { filterIds.contains($0.id) }

        await MainActor.run {
            assignmentFilters = relevantFilters
        }
    }
}

// MARK: - Filter Summary Card
struct FilterSummaryCard: View {
    let filterId: String
    let filter: AssignmentFilter?
    let groupSettings: [GroupAssignmentSettings]
    @State private var isExpanded = false

    /// Find groups using this filter
    private var groupsUsingFilter: [(groupId: String, groupName: String, mode: AssignmentFilterMode)] {
        groupSettings.compactMap { setting in
            guard let id = setting.assignmentFilterId,
                  id == filterId else { return nil }
            let mode = setting.assignmentFilterMode ?? .include
            return (setting.groupId, setting.groupName, mode)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Image(systemName: filter?.platform.icon ?? "line.3.horizontal.decrease.circle")
                            .foregroundColor(.blue)
                            .font(.title3)

                        Text(filter?.displayName ?? filterId)
                            .font(.headline)
                    }

                    if let platform = filter?.platform {
                        Text(platform.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Expand/collapse button
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }

            // Groups using this filter
            if !groupsUsingFilter.isEmpty {
                HStack(spacing: 8) {
                    Text("Used by \(groupsUsingFilter.count) group\(groupsUsingFilter.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Show modes
                    ForEach(Array(Set(groupsUsingFilter.map { $0.mode })), id: \.self) { mode in
                        FilterModeBadge(mode: mode)
                    }
                }
            }

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    // Filter rule
                    if let rule = filter?.rule {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Filter Rule:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(rule)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(8)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }

                    // Groups using this filter
                    if !groupsUsingFilter.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Applied to:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(groupsUsingFilter, id: \.groupId) { item in
                                HStack(spacing: 8) {
                                    FilterModeBadge(mode: item.mode)

                                    Text(item.groupName)
                                        .font(.caption)
                                }
                            }
                        }
                    }

                    // Filter description
                    if let description = filter?.filterDescription {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Description:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Filter Mode Badge
struct FilterModeBadge: View {
    let mode: AssignmentFilterMode

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: mode == .include ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption2)
            Text(mode.rawValue.capitalized)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(mode == .include ? Color.green : Color.red)
        .cornerRadius(4)
    }
}

// MARK: - Export Document
struct ExportDocument: FileDocument {
    static var readableContentTypes = [UTType.data]

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.data = data
        } else {
            self.data = Data()
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
