import SwiftUI

struct ReportsView: View {
    @StateObject private var assignmentService = AssignmentService.shared
    @StateObject private var deviceService = DeviceService.shared
    @StateObject private var appService = ApplicationService.shared
    @State private var selectedTimeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case day = "24 Hours"
        case week = "7 Days"
        case month = "30 Days"

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Selector
                HStack {
                    Text("Time Range")
                        .font(.headline)

                    Spacer()

                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)

                // Assignment Statistics
                AssignmentStatsSection(stats: assignmentService.getAssignmentStatistics())

                // Recent Activity (moved from Dashboard)
                RecentActivitySection(assignments: assignmentService.assignmentHistory)

                // Compliance Overview
                ComplianceOverviewSection(devices: deviceService.devices)

                // Application Deployment Stats
                ApplicationDeploymentSection(applications: appService.applications)
            }
            .padding()
        }
        .navigationTitle("Reports")
    }
}

struct AssignmentStatsSection: View {
    let stats: AssignmentStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assignment Statistics")
                .font(.headline)

            HStack(spacing: 16) {
                ReportStatCard(
                    title: "Total",
                    value: "\(stats.total)",
                    icon: "list.bullet",
                    color: .blue
                )

                ReportStatCard(
                    title: "Completed",
                    value: "\(stats.completed)",
                    icon: "checkmark.circle",
                    color: .green
                )

                ReportStatCard(
                    title: "Failed",
                    value: "\(stats.failed)",
                    icon: "xmark.circle",
                    color: .red
                )

                ReportStatCard(
                    title: "Success Rate",
                    value: String(format: "%.1f%%", stats.successRate),
                    icon: "percent",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct RecentActivitySection: View {
    let assignments: [Assignment]

    var recentAssignments: [Assignment] {
        assignments.sorted { $0.createdDate > $1.createdDate }
            .prefix(10)  // Show more items in Reports view
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                if !assignments.isEmpty {
                    Text("\(assignments.count) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if recentAssignments.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(recentAssignments) { assignment in
                    HStack {
                        Image(systemName: assignment.status.icon)
                            .foregroundColor(Color.systemColor(named: assignment.status.color))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(assignment.applicationName) → \(assignment.groupName)")
                                .font(.subheadline)
                                .lineLimit(1)

                            HStack {
                                Text(assignment.createdDate.formatted(.relative(presentation: .named)))
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Label(assignment.intent.displayName, systemImage: assignment.intent.icon)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Text(assignment.status.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.systemColor(named: assignment.status.color).opacity(0.2))
                            .cornerRadius(4)
                    }
                    .padding(.vertical, 4)

                    if assignment.id != recentAssignments.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ComplianceOverviewSection: View {
    let devices: [Device]

    var complianceData: [(state: String, count: Int, color: Color)] {
        let grouped = Dictionary(grouping: devices) { $0.complianceState }
        return [
            ("Compliant", grouped[.compliant]?.count ?? 0, .green),
            ("Non-Compliant", grouped[.noncompliant]?.count ?? 0, .red),
            ("In Grace Period", grouped[.inGracePeriod]?.count ?? 0, .orange),
            ("Unknown", grouped[.unknown]?.count ?? 0, .gray)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Compliance Overview")
                .font(.headline)

            ForEach(complianceData, id: \.state) { item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)

                    Text(item.state)
                        .font(.subheadline)

                    Spacer()

                    Text("\(item.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(String(format: "%.0f%%", devices.isEmpty ? 0 : (Double(item.count) / Double(devices.count) * 100)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            if !devices.isEmpty {
                Divider()
                HStack {
                    Text("Total Devices")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(devices.count)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ApplicationDeploymentSection: View {
    let applications: [Application]

    var topDeployedApps: [Application] {
        applications
            .filter { ($0.assignments?.count ?? 0) > 0 }
            .sorted { ($0.assignments?.count ?? 0) > ($1.assignments?.count ?? 0) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Deployed Applications")
                .font(.headline)

            if topDeployedApps.isEmpty {
                Text("No deployed applications")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(topDeployedApps, id: \.id) { app in
                    HStack {
                        Image(systemName: app.appType.icon)
                            .foregroundColor(.accentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.displayName)
                                .font(.subheadline)
                                .lineLimit(1)

                            Text(app.publisher ?? "Unknown Publisher")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(app.assignments?.count ?? 0)")
                                .font(.headline)
                            Text("assignments")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    if app.id != topDeployedApps.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// Report Stat Card
struct ReportStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}