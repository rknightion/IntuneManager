import SwiftUI

struct ReportsView: View {
    @StateObject private var assignmentService = AssignmentService.shared
    @StateObject private var deviceService = DeviceService.shared
    @StateObject private var appService = ApplicationService.shared
    @State private var selectedTimeRange: TimeRange = .week
    @State private var expandedSection: ReportSection? = nil
    @State private var intuneStats: IntuneAssignmentStats?
    @State private var isLoadingStats = false

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

    enum ReportSection: String, CaseIterable {
        case assignmentStatistics = "Assignment Statistics"
        case deviceCompliance = "Device Compliance Overview"
        case topDeployedApps = "Top Deployed Applications"
        case recentActivity = "Recent Activity"

        var icon: String {
            switch self {
            case .assignmentStatistics: return "chart.bar.fill"
            case .deviceCompliance: return "checkmark.shield.fill"
            case .topDeployedApps: return "apps.ipad"
            case .recentActivity: return "clock.fill"
            }
        }

        var color: Color {
            switch self {
            case .assignmentStatistics: return .blue
            case .deviceCompliance: return .green
            case .topDeployedApps: return .purple
            case .recentActivity: return .orange
            }
        }

        var description: String {
            switch self {
            case .assignmentStatistics: return "View assignment metrics from Intune"
            case .deviceCompliance: return "Monitor device compliance states"
            case .topDeployedApps: return "See most deployed applications"
            case .recentActivity: return "Track recent assignment operations"
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

                // Report Section Buttons Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(ReportSection.allCases, id: \.self) { section in
                        ReportSectionButton(
                            section: section,
                            isExpanded: expandedSection == section,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if expandedSection == section {
                                        expandedSection = nil
                                    } else {
                                        expandedSection = section
                                        if section == .assignmentStatistics {
                                            Task {
                                                await loadIntuneStatistics()
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }
                }

                // Expanded Section Content
                if let expandedSection = expandedSection {
                    VStack {
                        switch expandedSection {
                        case .assignmentStatistics:
                            IntuneAssignmentStatsSection(
                                stats: intuneStats,
                                isLoading: isLoadingStats
                            )
                        case .deviceCompliance:
                            ComplianceOverviewSection(devices: deviceService.devices)
                        case .topDeployedApps:
                            ApplicationDeploymentSection(applications: appService.applications)
                        case .recentActivity:
                            RecentActivitySection(assignments: assignmentService.assignmentHistory)
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
            }
            .padding()
        }
        .navigationTitle("Reports")
    }

    private func loadIntuneStatistics() async {
        isLoadingStats = true
        do {
            intuneStats = try await assignmentService.fetchIntuneAssignmentStatistics()
        } catch {
            Logger.shared.error("Failed to fetch Intune statistics: \(error)", category: .ui)
        }
        isLoadingStats = false
    }
}

// Report Section Button Component
struct ReportSectionButton: View {
    let section: ReportsView.ReportSection
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: section.icon)
                        .font(.title2)
                        .foregroundColor(.white)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(section.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(section.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                        .minimumScaleFactor(0.9)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(section.color.gradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isExpanded ? Color.white.opacity(0.5) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isExpanded ? 1.02 : 1.0)
    }
}

// Intune Assignment Statistics Section
struct IntuneAssignmentStatsSection: View {
    let stats: IntuneAssignmentStats?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Assignment Statistics (from Intune)")
                .font(.headline)

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Fetching statistics from Intune...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
            } else if let stats = stats {
                HStack(spacing: 16) {
                    ReportStatCard(
                        title: "Total Assignments",
                        value: "\(stats.totalAssignments)",
                        icon: "list.bullet",
                        color: .blue
                    )

                    ReportStatCard(
                        title: "Apps with Assignments",
                        value: "\(stats.totalAppsWithAssignments)",
                        icon: "app.badge.checkmark",
                        color: .green
                    )

                    ReportStatCard(
                        title: "Total Apps",
                        value: "\(stats.totalApps)",
                        icon: "square.grid.3x3",
                        color: .purple
                    )
                }

                // Assignment breakdown by intent
                if !stats.assignmentsByIntent.isEmpty {
                    Divider()

                    Text("Assignments by Intent")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)

                    ForEach(Array(stats.assignmentsByIntent.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { intent in
                        HStack {
                            Label(intent.displayName, systemImage: intent.icon)
                                .font(.subheadline)
                            Spacer()
                            Text("\(stats.assignmentsByIntent[intent] ?? 0)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } else {
                Text("No statistics available. Tap to fetch from Intune.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
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
            .prefix(10)
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

// Report Stat Card (without success rate)
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