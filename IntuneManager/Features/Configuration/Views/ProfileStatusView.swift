import SwiftUI
import Charts
import Combine

struct ProfileStatusView: View {
    let profile: ConfigurationProfile
    @StateObject private var viewModel = ProfileStatusViewModel()
    @State private var selectedTimeRange = TimeRange.last7Days
    @State private var showingDeviceList = false

    enum TimeRange: String, CaseIterable {
        case last24Hours = "24 Hours"
        case last7Days = "7 Days"
        case last30Days = "30 Days"

        var days: Int {
            switch self {
            case .last24Hours: return 1
            case .last7Days: return 7
            case .last30Days: return 30
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Deployment Summary Card
                deploymentSummaryCard

                // Compliance Status Chart
                complianceChart

                // Device Status List
                deviceStatusSection

                // Error Summary
                if !viewModel.deploymentErrors.isEmpty {
                    errorSummarySection
                }
            }
            .padding()
        }
        .navigationTitle("Deployment Status")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { Task { await viewModel.refreshStatus() } }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isLoading)
            }
        }
        .task {
            await viewModel.loadDeploymentStatus(for: profile)
        }
        .sheet(isPresented: $showingDeviceList) {
            DeviceComplianceListView(
                profile: profile,
                devices: viewModel.deviceStatuses
            )
        }
    }

    var deploymentSummaryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Deployment Overview")
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

            HStack(spacing: 20) {
                StatusMetric(
                    title: "Total Devices",
                    value: "\(viewModel.totalDevices)",
                    icon: "laptopcomputer",
                    color: .blue
                )

                StatusMetric(
                    title: "Compliant",
                    value: "\(viewModel.compliantDevices)",
                    percentage: viewModel.compliancePercentage,
                    icon: "checkmark.shield.fill",
                    color: .green
                )

                StatusMetric(
                    title: "Non-Compliant",
                    value: "\(viewModel.nonCompliantDevices)",
                    icon: "exclamationmark.triangle.fill",
                    color: .orange
                )

                StatusMetric(
                    title: "Errors",
                    value: "\(viewModel.errorDevices)",
                    icon: "xmark.octagon.fill",
                    color: .red
                )
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var complianceChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compliance Trend")
                .font(.headline)

            if viewModel.complianceHistory.isEmpty {
                ContentUnavailableView(
                    "No Data Available",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("Compliance data will appear here once devices report status")
                )
                .frame(height: 200)
            } else {
                Chart(viewModel.complianceHistory) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Compliance", dataPoint.complianceRate)
                    )
                    .foregroundStyle(.green)

                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Compliance", dataPoint.complianceRate)
                    )
                    .foregroundStyle(.green.opacity(0.1))
                }
                .frame(height: 200)
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Double.self) {
                                Text("\(Int(intValue))%")
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var deviceStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Device Status")
                    .font(.headline)
                Spacer()
                Button("View All") {
                    showingDeviceList = true
                }
                .buttonStyle(.bordered)
            }

            if viewModel.deviceStatuses.isEmpty {
                HStack {
                    Image(systemName: "laptopcomputer.slash")
                        .foregroundColor(.secondary)
                    Text("No device status available")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical)
            } else {
                ForEach(viewModel.deviceStatuses.prefix(5)) { status in
                    DeviceStatusRow(status: status)
                }

                if viewModel.deviceStatuses.count > 5 {
                    Button(action: { showingDeviceList = true }) {
                        Label("Show \(viewModel.deviceStatuses.count - 5) more", systemImage: "chevron.down")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
            }
        }
        .padding()
        .background(Theme.Colors.secondaryBackground)
        .cornerRadius(10)
    }

    var errorSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Deployment Errors", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
                Text("\(viewModel.deploymentErrors.count) errors")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(viewModel.deploymentErrors.prefix(3)) { error in
                DeploymentErrorRow(error: error)
            }

            if viewModel.deploymentErrors.count > 3 {
                Text("+ \(viewModel.deploymentErrors.count - 3) more errors")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }
}

struct StatusMetric: View {
    let title: String
    let value: String
    var percentage: Double? = nil
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(alignment: .bottom, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)

                if let percentage = percentage {
                    Text("\(Int(percentage))%")
                        .font(.caption)
                        .foregroundColor(color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(color.opacity(0.1))
                        .cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DeviceStatusRow: View {
    let status: DeviceComplianceStatus

    var body: some View {
        HStack {
            Image(systemName: status.isCompliant ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(status.isCompliant ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(status.deviceName)
                    .font(.subheadline)

                HStack {
                    Text(status.userName ?? "Unknown User")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("Last sync: \(status.lastSync, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let errorMessage = status.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .help(errorMessage)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DeploymentErrorRow: View {
    let error: DeploymentError

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorCode)
                    .font(.caption)
                    .fontWeight(.medium)

                Text(error.errorDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Affected: \(error.affectedDeviceCount) devices")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct DeviceComplianceListView: View {
    let profile: ConfigurationProfile
    let devices: [DeviceComplianceStatus]
    @State private var searchText = ""
    @State private var showOnlyNonCompliant = false
    @Environment(\.dismiss) private var dismiss

    var filteredDevices: [DeviceComplianceStatus] {
        var filtered = devices

        if !searchText.isEmpty {
            filtered = filtered.filter { device in
                device.deviceName.localizedCaseInsensitiveContains(searchText) ||
                (device.userName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        if showOnlyNonCompliant {
            filtered = filtered.filter { !$0.isCompliant }
        }

        return filtered
    }

    var body: some View {
        NavigationStack {
            List(filteredDevices) { device in
                DeviceStatusRow(status: device)
            }
            .searchable(text: $searchText, prompt: "Search devices...")
            .navigationTitle("Device Compliance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Toggle(isOn: $showOnlyNonCompliant) {
                        Label("Non-Compliant Only", systemImage: "exclamationmark.triangle")
                    }
                    .toggleStyle(.button)
                }
            }
        }
    }
}

// MARK: - View Model

@MainActor
final class ProfileStatusViewModel: ObservableObject {
    @Published var totalDevices = 0
    @Published var compliantDevices = 0
    @Published var nonCompliantDevices = 0
    @Published var errorDevices = 0
    @Published var deviceStatuses: [DeviceComplianceStatus] = []
    @Published var complianceHistory: [ComplianceDataPoint] = []
    @Published var deploymentErrors: [DeploymentError] = []
    @Published var isLoading = false
    @Published var error: Error?

    var compliancePercentage: Double {
        guard totalDevices > 0 else { return 0 }
        return Double(compliantDevices) / Double(totalDevices) * 100
    }

    private let configurationService = ConfigurationService.shared

    func loadDeploymentStatus(for profile: ConfigurationProfile) async {
        isLoading = true
        defer { isLoading = false }

        // Simulate loading deployment status
        // In a real implementation, this would fetch from Graph API
        await simulateData()
    }

    func refreshStatus() async {
        await simulateData()
    }

    private func simulateData() async {
        // Simulate some data for demonstration
        totalDevices = 150
        compliantDevices = 120
        nonCompliantDevices = 25
        errorDevices = 5

        // Generate sample compliance history
        complianceHistory = (0..<7).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -dayOffset, to: Date())!
            let rate = 70 + Double.random(in: 0...30)
            return ComplianceDataPoint(date: date, complianceRate: rate)
        }.reversed()

        // Generate sample device statuses
        deviceStatuses = [
            DeviceComplianceStatus(
                id: "1",
                deviceName: "MacBook-Pro-001",
                userName: "John Doe",
                isCompliant: true,
                lastSync: Date(timeIntervalSinceNow: -3600)
            ),
            DeviceComplianceStatus(
                id: "2",
                deviceName: "iPhone-12-002",
                userName: "Jane Smith",
                isCompliant: false,
                lastSync: Date(timeIntervalSinceNow: -7200),
                errorMessage: "Policy conflict detected"
            ),
            DeviceComplianceStatus(
                id: "3",
                deviceName: "iPad-Air-003",
                userName: "Bob Johnson",
                isCompliant: true,
                lastSync: Date(timeIntervalSinceNow: -1800)
            )
        ]

        // Generate sample errors
        deploymentErrors = [
            DeploymentError(
                id: "E001",
                errorCode: "POLICY_CONFLICT",
                errorDescription: "Conflicting settings with existing profile",
                affectedDeviceCount: 3
            )
        ]
    }
}

// MARK: - Data Models

struct DeviceComplianceStatus: Identifiable {
    let id: String
    let deviceName: String
    let userName: String?
    let isCompliant: Bool
    let lastSync: Date
    let errorMessage: String?

    init(id: String, deviceName: String, userName: String? = nil, isCompliant: Bool, lastSync: Date, errorMessage: String? = nil) {
        self.id = id
        self.deviceName = deviceName
        self.userName = userName
        self.isCompliant = isCompliant
        self.lastSync = lastSync
        self.errorMessage = errorMessage
    }
}

struct ComplianceDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let complianceRate: Double
}

struct DeploymentError: Identifiable {
    let id: String
    let errorCode: String
    let errorDescription: String
    let affectedDeviceCount: Int
}
