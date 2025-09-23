import SwiftUI

struct RecentActivityView: View {
    @StateObject private var auditLogService = AuditLogService.shared
    @State private var selectedLog: AuditLog?
    @State private var showingDetail = false
    @State private var hoursFilter: Int = 72
    @State private var limitFilter: Int = 50

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with filters
            HStack {
                Text("Recent Intune Activity")
                    .font(.headline)

                Spacer()

                Menu {
                    Section("Time Range") {
                        Button("Last 24 hours") {
                            hoursFilter = 24
                            Task { await refreshLogs() }
                        }
                        Button("Last 72 hours") {
                            hoursFilter = 72
                            Task { await refreshLogs() }
                        }
                        Button("Last 7 days") {
                            hoursFilter = 168
                            Task { await refreshLogs() }
                        }
                    }

                    Section("Display Limit") {
                        Button("Show 25 entries") {
                            limitFilter = 25
                            Task { await refreshLogs() }
                        }
                        Button("Show 50 entries") {
                            limitFilter = 50
                            Task { await refreshLogs() }
                        }
                        Button("Show 100 entries") {
                            limitFilter = 100
                            Task { await refreshLogs() }
                        }
                    }
                } label: {
                    Label("Filter", systemImage: "line.horizontal.3.decrease.circle")
                        .font(.caption)
                }
                .menuStyle(.borderlessButton)

                Button(action: {
                    Task {
                        await refreshLogs()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .help("Refresh audit logs")
            }

            if auditLogService.isLoading {
                HStack {
                    ProgressView()
                    Text("Fetching audit logs from Intune...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if let error = auditLogService.errorMessage {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Failed to fetch audit logs")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if auditLogService.auditLogs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("No recent activity found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button("Fetch Audit Logs") {
                        Task {
                            await refreshLogs()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(auditLogService.auditLogs, id: \.id) { log in
                            AuditLogRow(log: log) {
                                selectedLog = log
                                showingDetail = true
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
            }

            // Summary footer
            if !auditLogService.auditLogs.isEmpty {
                Divider()
                HStack {
                    Text("Showing \(auditLogService.auditLogs.count) of last \(hoursFilter) hours")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let lastUpdate = auditLogService.auditLogs.first?.activityDateTime {
                        Text("Most recent: \(lastUpdate.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .task {
            if auditLogService.auditLogs.isEmpty {
                await refreshLogs()
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let log = selectedLog {
                AuditLogDetailView(log: log)
            }
        }
    }

    private func refreshLogs() async {
        await auditLogService.fetchAllAuditLogsFields(hoursAgo: hoursFilter, limit: limitFilter)
    }
}

struct AuditLogRow: View {
    let log: AuditLog
    let onTap: () -> Void

    var statusColor: Color {
        switch log.activityResult?.lowercased() {
        case "success": return .green
        case "failure", "failed": return .red
        case "pending": return .orange
        default: return .blue
        }
    }

    var activityIcon: String {
        if let type = log.activityType?.lowercased() {
            if type.contains("create") || type.contains("add") {
                return "plus.circle"
            } else if type.contains("update") || type.contains("edit") || type.contains("modify") {
                return "pencil.circle"
            } else if type.contains("delete") || type.contains("remove") {
                return "trash.circle"
            } else if type.contains("assign") {
                return "person.2.circle"
            } else if type.contains("sync") {
                return "arrow.triangle.2.circlepath"
            }
        }
        return "circle"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)

                // Activity icon
                Image(systemName: activityIcon)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    // Activity name
                    Text(log.activity ?? log.displayName ?? "Unknown Activity")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundColor(.primary)

                    // Actor and time
                    HStack(spacing: 4) {
                        if let actor = log.actor {
                            Label(actor.displayName, systemImage: "person.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        if log.actor != nil && log.activityDateTime != nil {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if let date = log.activityDateTime {
                            Text(date.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Target resources
                    if let resources = log.resources, !resources.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Text(resources.compactMap { $0.displayName ?? $0.type }.joined(separator: ", "))
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    // Component and category
                    if let component = log.componentName ?? log.category {
                        Label(component, systemImage: "tag.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Result badge
                if let result = log.activityResult {
                    Text(result.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.2))
                        .foregroundColor(statusColor)
                        .cornerRadius(4)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.03))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}