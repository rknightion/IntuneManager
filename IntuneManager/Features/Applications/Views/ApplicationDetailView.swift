import SwiftUI
import Combine

@MainActor
final class ApplicationDetailViewModel: ObservableObject {
    @Published var application: Application
    @Published var installSummary: Application.InstallSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isDeleting = false
    @Published var showingDeleteConfirmation = false

    private let appService = ApplicationService.shared
    private var hasLoadedOnce = false

    init(application: Application) {
        self.application = application
        self.installSummary = application.installSummary
    }

    func loadDetails(force: Bool = false) async {
        guard !isLoading else {
            Logger.shared.debug("Already loading app details, skipping", category: .ui)
            return
        }
        if hasLoadedOnce && !force {
            Logger.shared.debug("App details already loaded, using cached", category: .ui)
            return
        }

        Logger.shared.info("Loading details for app: \(application.displayName) (ID: \(application.id))", category: .ui)
        isLoading = true

        do {
            let fresh = try await appService.fetchApplication(id: application.id)
            application = fresh
            errorMessage = nil
            hasLoadedOnce = true
            Logger.shared.info("Successfully loaded details for \(fresh.displayName)", category: .ui)

            // Install summary might be included in the app object
            if let summary = fresh.installSummary {
                installSummary = summary
                Logger.shared.debug("Install summary included in response", category: .ui)
            } else if fresh.hasAssignments {
                // Install summary endpoints are not available for many app types and cause 400 errors
                // Disabling this feature to prevent console spam
                Logger.shared.debug("Install summary fetching disabled - not supported for many app types", category: .ui)
                installSummary = nil
            } else {
                // No assignments, no install summary needed
                Logger.shared.debug("App has no assignments, skipping install summary fetch", category: .ui)
                installSummary = nil
            }

            isLoading = false
        } catch {
            Logger.shared.error("Failed to load app details: \(error.localizedDescription)", category: .ui)
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func deleteApplication() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await appService.deleteApplication(application.id)
            Logger.shared.info("Successfully deleted application: \(application.displayName)")
            return true
        } catch {
            Logger.shared.error("Failed to delete application: \(error.localizedDescription)")
            errorMessage = "Failed to delete: \(error.localizedDescription)"
            return false
        }
    }
}

struct ApplicationDetailView: View {
    @StateObject private var viewModel: ApplicationDetailViewModel
    @Environment(\.dismiss) private var dismiss

    init(application: Application) {
        _viewModel = StateObject(wrappedValue: ApplicationDetailViewModel(application: application))
    }

    var body: some View {
        List {
            overviewSection

            if let description = viewModel.application.appDescription, !description.isEmpty {
                Section("Description") {
                    Text(description)
                        .font(.body)
                }
            }

            platformSection
            assignmentsSection
            installSummarySection
            commandSection
            linksSection

            // Delete Section
            Section {
                Button(role: .destructive) {
                    viewModel.showingDeleteConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Application")
                    }
                    .foregroundColor(.red)
                }
                .disabled(viewModel.isDeleting)
            } footer: {
                Text("This will permanently delete the application from Intune. All assignments will be removed. The app will not be uninstalled from devices.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let error = viewModel.errorMessage {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundColor(.red)
                        .font(.footnote)
                        .lineLimit(nil)
                }
            }
        }
        .navigationTitle(viewModel.application.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if viewModel.isLoading || viewModel.isDeleting {
                    ProgressView()
                } else {
                    Button {
                        Task { await viewModel.loadDetails(force: true) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh from Microsoft Graph")
                }
            }
        }
        .confirmationDialog(
            "Delete Application",
            isPresented: $viewModel.showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteApplication() {
                        dismiss()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete '\(viewModel.application.displayName)'? This action cannot be undone.")
        }
        .task {
            Logger.shared.info("ApplicationDetailView appeared for: \(viewModel.application.displayName)", category: .ui)
            await viewModel.loadDetails()
        }
        .refreshable {
            await viewModel.loadDetails(force: true)
        }
    }

    private var overviewSection: some View {
        Section("Overview") {
            KeyValueRow(label: "Publisher", value: viewModel.application.publisher ?? "—")
            KeyValueRow(label: "Type", value: viewModel.application.appType.displayName)
            if let version = viewModel.application.version, !version.isEmpty {
                KeyValueRow(label: "Version", value: version)
            }
            if let bundleId = viewModel.application.bundleId, !bundleId.isEmpty {
                KeyValueRow(label: "Bundle ID", value: bundleId)
            }
            KeyValueRow(label: "State", value: viewModel.application.publishingState.displayName)
            KeyValueRow(label: "Created", value: format(date: viewModel.application.createdDateTime))
            KeyValueRow(label: "Updated", value: format(date: viewModel.application.lastModifiedDateTime))
        }
    }

    private var platformSection: some View {
        Section("Platforms & Requirements") {
            if let deviceType = viewModel.application.applicableDeviceType {
                let targets = platformTargets(from: deviceType)
                KeyValueRow(label: "Targets", value: targets.isEmpty ? "Custom" : targets.joined(separator: ", "))
            }

            if let minOS = viewModel.application.minimumSupportedOperatingSystem {
                if let ios = minOS.iOS, !ios.isEmpty {
                    KeyValueRow(label: "Minimum iOS", value: ios)
                }
                if let mac = minOS.macOS, !mac.isEmpty {
                    KeyValueRow(label: "Minimum macOS", value: mac)
                }
            }

            if let size = viewModel.application.size, size > 0 {
                KeyValueRow(label: "Package Size", value: format(bytes: size))
            }
        }
    }

    private var assignmentsSection: some View {
        Section("Assignments") {
            if let assignments = viewModel.application.assignments, !assignments.isEmpty {
                ForEach(assignments) { assignment in
                    AppAssignmentRow(assignment: assignment, appType: viewModel.application.appType)
                }
            } else if viewModel.errorMessage != nil {
                // Only show error message if there was an actual error fetching data
                Text("No assignments configured for this app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                // Show 0 assignments when data loaded successfully but no assignments exist
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                    Text("0 assignments")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var installSummarySection: some View {
        Section("Install Summary") {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading install metrics...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if let summary = viewModel.installSummary {
                // Device metrics
                if summary.installedDeviceCount > 0 || summary.pendingInstallDeviceCount > 0 ||
                   summary.failedDeviceCount > 0 || summary.notApplicableDeviceCount > 0 {
                    Text("Device Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    summaryRow(label: "Installed", value: summary.installedDeviceCount, color: .green)
                    summaryRow(label: "Pending", value: summary.pendingInstallDeviceCount, color: .orange)
                    summaryRow(label: "Failed", value: summary.failedDeviceCount, color: .red)
                    summaryRow(label: "Not Applicable", value: summary.notApplicableDeviceCount, color: .gray)
                }

                // User metrics
                if summary.installedUserCount > 0 || summary.pendingInstallUserCount > 0 ||
                   summary.failedUserCount > 0 {
                    Divider()
                    Text("User Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)

                    summaryRow(label: "Installed", value: summary.installedUserCount, color: .green)
                    summaryRow(label: "Pending", value: summary.pendingInstallUserCount, color: .orange)
                    summaryRow(label: "Failed", value: summary.failedUserCount, color: .red)
                }

                // Show message if no install data
                if summary.installedDeviceCount == 0 && summary.pendingInstallDeviceCount == 0 &&
                   summary.failedDeviceCount == 0 && summary.notApplicableDeviceCount == 0 &&
                   summary.installedUserCount == 0 && summary.pendingInstallUserCount == 0 &&
                   summary.failedUserCount == 0 {
                    Text("No installation data available yet.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if viewModel.errorMessage != nil {
                Text("No install data available. Assign this app to groups to see install metrics.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Install metrics will appear after assignment deployment.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var commandSection: some View {
        Section("Deployment Commands") {
            if let install = viewModel.application.installCommandLine, !install.isEmpty {
                KeyValueRow(label: "Install", value: install)
            }
            if let uninstall = viewModel.application.uninstallCommandLine, !uninstall.isEmpty {
                KeyValueRow(label: "Uninstall", value: uninstall)
            }
            if (viewModel.application.installCommandLine?.isEmpty ?? true) && (viewModel.application.uninstallCommandLine?.isEmpty ?? true) {
                Text("No custom command lines configured.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var linksSection: some View {
        Section("Links") {
            if let privacyUrl = viewModel.application.privacyInformationUrl, !privacyUrl.isEmpty {
                KeyValueRow(label: "Privacy", value: privacyUrl)
            }
            if let infoUrl = viewModel.application.informationUrl, !infoUrl.isEmpty {
                KeyValueRow(label: "Information", value: infoUrl)
            }
            if let appStoreUrl = viewModel.application.appStoreUrl, !appStoreUrl.isEmpty {
                KeyValueRow(label: "Store", value: appStoreUrl)
            }
        }
    }

    private func platformTargets(from deviceType: Application.ApplicableDeviceType) -> [String] {
        var targets: [String] = []
        if deviceType.mac { targets.append("macOS") }
        if deviceType.iPad { targets.append("iPadOS") }
        if deviceType.iPhoneAndIPod { targets.append("iOS") }
        return targets
    }

    private func format(date: Date) -> String {
        DateFormatter.applicationDetail.string(from: date)
    }

    private func format(bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func summaryRow(label: String, value: Int, color: Color = .primary) -> some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.subheadline)
            Spacer()
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(value > 0 ? color : .secondary)
        }
    }
}

private struct KeyValueRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - App Assignment Row with Settings
struct AppAssignmentRow: View {
    let assignment: AppAssignment
    let appType: Application.AppType
    @State private var isExpanded = false

    var intentColor: Color {
        switch assignment.intent {
        case .required:
            return .red
        case .available, .availableWithoutEnrollment:
            return .blue
        case .uninstall:
            return .orange
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.target.groupName ?? assignment.target.type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        HStack(spacing: 8) {
                            // Intent badge with color
                            Label(assignment.intent.displayName, systemImage: assignment.intent.icon)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(intentColor.opacity(0.15))
                                .foregroundColor(intentColor)
                                .cornerRadius(4)

                            Text(assignment.target.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)

                            // Filter badge if present
                            if let filterId = getFilterId(from: assignment.settings) {
                                let filterMode = getFilterMode(from: assignment.settings)

                                HStack(spacing: 4) {
                                    Image(systemName: "line.horizontal.3.decrease.circle.fill")
                                        .font(.caption2)
                                    Text("Filter")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background((filterMode == .exclude ? Color.red : Color.green).opacity(0.15))
                                .foregroundColor(filterMode == .exclude ? .red : .green)
                                .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            // Expandable settings
            if isExpanded {
                Divider()
                    .padding(.vertical, 4)

                AppAssignmentSettingsDetail(settings: assignment.settings, appType: appType)
                    .padding(.leading, 8)
            }
        }
        .padding(.vertical, 4)
    }

    // Helper to get filter ID from settings
    private func getFilterId(from settings: AppAssignment.AssignmentSettings?) -> String? {
        guard let settings = settings else { return nil }
        // AppAssignment.AssignmentSettings is a protocol/wrapper, need to check the actual type
        // For now, return nil - this will be populated when we have real assignment data
        return nil
    }

    private func getFilterMode(from settings: AppAssignment.AssignmentSettings?) -> AssignmentFilterMode {
        return .include
    }
}

// MARK: - App Assignment Settings Detail
struct AppAssignmentSettingsDetail: View {
    let settings: AppAssignment.AssignmentSettings?
    let appType: Application.AppType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assignment Settings")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Since AppAssignment.AssignmentSettings is a nested type, we'll show
            // a placeholder for now. In the future, we can decode the actual settings
            // from the Graph API response.
            Text("Settings details available after assignment")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

private extension DateFormatter {
    static let applicationDetail: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
