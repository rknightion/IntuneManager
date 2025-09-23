import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var deviceService = DeviceService.shared
    @StateObject private var appService = ApplicationService.shared
    @StateObject private var groupService = GroupService.shared
    @StateObject private var assignmentService = AssignmentService.shared
    @State private var selectedTimeRange: TimeRange = .week
    @State private var intuneStats: IntuneAssignmentStats?

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
                    intuneStats: intuneStats
                )

                // Charts
                HStack(spacing: 20) {
                    ComplianceChartView(devices: deviceService.devices)
                    PlatformDistributionView(devices: deviceService.devices)
                }
                .frame(height: 300)
            }
            .padding()
        }
        .navigationTitle("Dashboard")
        .onAppear {
            Task {
                await loadDashboardData()
            }
        }
    }

    private func loadDashboardData() async {
        // Use Task to avoid state updates during view rendering
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = try? await self.deviceService.fetchDevices()
            }
            group.addTask {
                _ = try? await self.appService.fetchApplications()
            }
            group.addTask {
                _ = try? await self.groupService.fetchGroups()
            }
            group.addTask {
                if let stats = try? await self.assignmentService.fetchIntuneAssignmentStatistics() {
                    await MainActor.run {
                        self.intuneStats = stats
                    }
                }
            }
        }
    }
}

struct HeaderSection: View {
    @Binding var timeRange: DashboardView.TimeRange
    @EnvironmentObject var authManager: AuthManagerV2

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
    let intuneStats: IntuneAssignmentStats?

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
                title: "Assignments",
                value: "\(intuneStats?.totalAssignments ?? 0)",
                icon: "link.circle",
                color: .orange
            )

            StatCard(
                title: "Apps Deployed",
                value: "\(intuneStats?.totalAppsWithAssignments ?? 0)",
                icon: "app.badge.checkmark",
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

// Removed unused structs - RecentActivitySection and QuickActionsSection moved to Reports
