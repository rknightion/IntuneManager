import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var deviceService = DeviceService.shared
    @StateObject private var appService = ApplicationService.shared
    @StateObject private var groupService = GroupService.shared
    @StateObject private var assignmentService = AssignmentService.shared
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
                // Header
                HeaderSection(timeRange: $selectedTimeRange)

                // Quick Stats
                StatsSection(
                    deviceCount: deviceService.devices.count,
                    appCount: appService.applications.count,
                    groupCount: groupService.groups.count,
                    assignmentStats: assignmentService.getAssignmentStatistics()
                )

                // Charts
                HStack(spacing: 20) {
                    ComplianceChartView(devices: deviceService.devices)
                    PlatformDistributionView(devices: deviceService.devices)
                }
                .frame(height: 300)

                // Recent Activity
                RecentActivitySection(assignments: assignmentService.assignmentHistory)

                // Quick Actions
                QuickActionsSection()
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .task {
            await loadDashboardData()
        }
    }

    private func loadDashboardData() async {
        async let devices = deviceService.fetchDevices()
        async let apps = appService.fetchApplications()
        async let groups = groupService.fetchGroups()

        _ = try? await (devices, apps, groups)
    }
}

struct HeaderSection: View {
    @Binding var timeRange: DashboardView.TimeRange
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome back, \(authManager.currentUser?.displayName ?? "User")")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(Date().formatted(date: .complete, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("Time Range", selection: $timeRange) {
                ForEach(DashboardView.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct StatsSection: View {
    let deviceCount: Int
    let appCount: Int
    let groupCount: Int
    let assignmentStats: AssignmentStatistics

    var body: some View {
        HStack(spacing: 16) {
            StatCard(
                title: "Devices",
                value: "\(deviceCount)",
                icon: "laptopcomputer",
                color: .blue
            )

            StatCard(
                title: "Applications",
                value: "\(appCount)",
                icon: "app.badge",
                color: .green
            )

            StatCard(
                title: "Groups",
                value: "\(groupCount)",
                icon: "person.3",
                color: .orange
            )

            StatCard(
                title: "Success Rate",
                value: String(format: "%.1f%%", assignmentStats.successRate),
                icon: "checkmark.circle",
                color: .purple
            )
        }
    }
}

struct StatCard: View {
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

struct ComplianceChartView: View {
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
        VStack(alignment: .leading) {
            Text("Compliance Status")
                .font(.headline)

            Chart(complianceData, id: \.state) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.6)
                )
                .foregroundStyle(item.color)
            }
            .chartBackground { _ in
                VStack {
                    Text("\(devices.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 16) {
                ForEach(complianceData, id: \.state) { item in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text("\(item.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct PlatformDistributionView: View {
    let devices: [Device]

    var platformData: [(platform: String, count: Int)] {
        let grouped = Dictionary(grouping: devices) { $0.operatingSystem }
        return grouped.map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Platform Distribution")
                .font(.headline)

            Chart(platformData, id: \.platform) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Platform", item.platform)
                )
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
            }

            HStack {
                ForEach(platformData, id: \.platform) { item in
                    VStack(spacing: 4) {
                        Text(item.platform)
                            .font(.caption2)
                        Text("\(item.count)")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
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
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.headline)
                Spacer()
                NavigationLink("View All") {
                    // AssignmentHistoryView()
                }
                .font(.caption)
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
                            .foregroundColor(Color(assignment.status.color))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(assignment.applicationName) → \(assignment.groupName)")
                                .font(.subheadline)
                                .lineLimit(1)

                            Text(assignment.createdDate.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Label(assignment.intent.displayName, systemImage: assignment.intent.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct QuickActionsSection: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Bulk Assignment",
                    icon: "arrow.right.square.fill",
                    color: .blue
                ) {
                    appState.selectedTab = .assignments
                }

                QuickActionButton(
                    title: "Sync Devices",
                    icon: "arrow.clockwise",
                    color: .green
                ) {
                    Task {
                        await appState.syncAll()
                    }
                }

                QuickActionButton(
                    title: "View Reports",
                    icon: "chart.bar.doc.horizontal",
                    color: .orange
                ) {
                    // Navigate to reports
                }

                QuickActionButton(
                    title: "Settings",
                    icon: "gearshape",
                    color: .purple
                ) {
                    // Open settings
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}