import SwiftUI

struct ApplicationListView: View {
    @StateObject private var appService = ApplicationService.shared
    @State private var searchText = ""
    @State private var assignmentFilter: AssignmentFilter = .all

    enum AssignmentFilter: String, CaseIterable {
        case all = "All"
        case unassigned = "Unassigned"
        case assigned = "Assigned"

        var systemImage: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .unassigned: return "square"
            case .assigned: return "checkmark.square"
            }
        }
    }

    var filteredApplications: [Application] {
        var apps = appService.searchApplications(query: searchText)

        switch assignmentFilter {
        case .all:
            break
        case .unassigned:
            apps = apps.filter { !$0.hasAssignments }
        case .assigned:
            apps = apps.filter { $0.hasAssignments }
        }

        return apps
    }

    var body: some View {
        Group {
            if appService.isLoading && appService.applications.isEmpty {
                ProgressView("Loading applications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Filter toolbar
                    Picker("Filter", selection: $assignmentFilter) {
                        ForEach(AssignmentFilter.allCases, id: \.self) { filter in
                            Label(filter.rawValue, systemImage: filter.systemImage).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    // Status bar
                    HStack {
                        Text("\(filteredApplications.count) of \(appService.applications.count) applications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 12) {
                            Label("\(appService.applications.filter { !$0.hasAssignments }.count)", systemImage: "square")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Label("\(appService.applications.filter { $0.hasAssignments }.count)", systemImage: "checkmark.square")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    List(filteredApplications) { app in
                        NavigationLink(destination: ApplicationDetailView(application: app)) {
                            ApplicationListRowView(application: app)
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search by name or publisher")
                }
            }
        }
        .navigationTitle("Applications")
        .task {
            Logger.shared.info("ApplicationListView appeared", category: .ui)
            do {
                Logger.shared.info("Loading applications list...", category: .ui)
                _ = try await appService.fetchApplications()
                Logger.shared.info("Applications list loaded successfully", category: .ui)
            } catch {
                Logger.shared.error("Failed to load applications: \(error.localizedDescription)", category: .ui)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .assignmentsDidChange)) { _ in
            // Refresh when assignments change
            Task {
                _ = try? await appService.fetchApplications(forceRefresh: true)
            }
        }
    }
}

// Simple row view for the application list (without selection/toggle functionality)
struct ApplicationListRowView: View {
    let application: Application

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(application.displayName)
                        .font(.system(.body, design: .default))
                        .lineLimit(1)

                    // Assignment indicator badge
                    if application.hasAssignments {
                        HStack(spacing: 3) {
                            Image(systemName: "person.2.fill")
                                .font(.caption2)
                            Text("\(application.assignmentCount)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .cornerRadius(4)
                    }
                }

                HStack {
                    Label(application.appType.displayName, systemImage: application.appType.icon)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let publisher = application.publisher {
                        Text("• \(publisher)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if let version = application.version {
                        Text("• v\(version)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Assignment summary if app has assignments
                if application.hasAssignments {
                    Text(application.assignmentSummary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let summary = application.installSummary {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(summary.installedDeviceCount) installed")
                        .font(.caption)
                        .foregroundColor(.green)
                    if summary.failedDeviceCount > 0 {
                        Text("\(summary.failedDeviceCount) failed")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}
