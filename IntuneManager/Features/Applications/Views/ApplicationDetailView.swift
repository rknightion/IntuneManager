import SwiftUI
import Combine

@MainActor
final class ApplicationDetailViewModel: ObservableObject {
    @Published var application: Application
    @Published var installSummary: Application.InstallSummary?
    @Published var isLoading = false
    @Published var errorMessage: String?

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
        defer { isLoading = false }

        do {
            let fresh = try await appService.fetchApplication(id: application.id)
            application = fresh
            errorMessage = nil
            hasLoadedOnce = true
            Logger.shared.info("Successfully loaded details for \(fresh.displayName)", category: .ui)

            if fresh.installSummary != nil {
                installSummary = fresh.installSummary
                Logger.shared.debug("Install summary included in response", category: .ui)
            } else {
                Logger.shared.debug("Fetching install summary separately", category: .ui)
                installSummary = try? await appService.fetchInstallSummary(appId: fresh.id)
            }
        } catch {
            Logger.shared.error("Failed to load app details: \(error.localizedDescription)", category: .ui)
            errorMessage = error.localizedDescription
        }
    }
}

struct ApplicationDetailView: View {
    @StateObject private var viewModel: ApplicationDetailViewModel

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
                if viewModel.isLoading {
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
        .onAppear {
            Logger.shared.info("ApplicationDetailView appeared for: \(viewModel.application.displayName)", category: .ui)
            Task {
                await viewModel.loadDetails()
            }
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignment.target.groupName ?? assignment.target.type.displayName)
                            .font(.subheadline)
                        HStack(spacing: 8) {
                            Label(assignment.intent.displayName, systemImage: assignment.intent.icon)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(assignment.target.type.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text("No assignment data returned for this application.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var installSummarySection: some View {
        Section("Install Summary") {
            if let summary = viewModel.installSummary {
                summaryRow(label: "Devices Installed", value: summary.installedDeviceCount)
                summaryRow(label: "Devices Pending", value: summary.pendingInstallDeviceCount)
                summaryRow(label: "Devices Failed", value: summary.failedDeviceCount)
                summaryRow(label: "Devices Not Applicable", value: summary.notApplicableDeviceCount)
                summaryRow(label: "Users Installed", value: summary.installedUserCount)
                summaryRow(label: "Users Pending", value: summary.pendingInstallUserCount)
                summaryRow(label: "Users Failed", value: summary.failedUserCount)
            } else {
                Text("Install metrics were not available from Graph.")
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

    private func summaryRow(label: String, value: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text("\(value)")
                .bold()
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

private extension DateFormatter {
    static let applicationDetail: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
