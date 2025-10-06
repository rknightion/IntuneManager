import SwiftUI

struct AssignmentProgressView: View {
    @ObservedObject var viewModel: BulkAssignmentViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingErrorDetails = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Processing Assignments")
                .font(.title2)
                .fontWeight(.semibold)

            if let progress = viewModel.progress {
                ProgressView(value: progress.percentComplete, total: 100)
                    .progressViewStyle(.linear)
                    .frame(height: 10)

                HStack {
                    VStack(alignment: .leading) {
                        Text("\(progress.completed) of \(progress.total)")
                            .font(.headline)
                        Text(progress.currentOperation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing) {
                        if progress.failed > 0 {
                            HStack {
                                Text("\(progress.failed) failed")
                                    .font(.caption)
                                    .foregroundColor(.red)
                                Button(action: { showingErrorDetails = true }) {
                                    Image(systemName: "info.circle")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Text("\(Int(progress.percentComplete))%")
                            .font(.headline)
                    }
                }
            } else {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }

            // Per-app progress section when processing
            if viewModel.isProcessing && !AssignmentService.shared.perAppProgress.isEmpty {
                PerAppProgressSection(perAppProgress: AssignmentService.shared.perAppProgress)
            }

            // Summary section when processing is complete (but not during verification)
            if !viewModel.isProcessing && !(viewModel.progress?.isVerifying ?? false) && (viewModel.completedAssignments.count > 0 || viewModel.failedAssignments.count > 0) {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Summary")
                        .font(.headline)

                    HStack {
                        Label("\(viewModel.completedAssignments.count) Successful", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)

                        Spacer()

                        if !viewModel.failedAssignments.isEmpty {
                            Label("\(viewModel.failedAssignments.count) Failed", systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }

                    // Group errors by type for better visibility
                    if !viewModel.failedAssignments.isEmpty {
                        let errorGroups = Dictionary(grouping: viewModel.failedAssignments) { $0.errorMessage ?? "Unknown error" }
                        ForEach(Array(errorGroups.keys.sorted()), id: \.self) { errorType in
                            HStack {
                                Text("• \(errorType)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("(\(errorGroups[errorType]?.count ?? 0))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }

            // Assignment Log View
            if viewModel.isProcessing || !AssignmentService.shared.assignmentLogs.isEmpty {
                AssignmentLogView(logs: AssignmentService.shared.assignmentLogs)
            }

            // Show buttons only when not processing AND not verifying
            let isActive = viewModel.isProcessing || (viewModel.progress?.isVerifying ?? false)

            if !isActive {
                VStack(spacing: 12) {
                    if !viewModel.failedAssignments.isEmpty {
                        HStack(spacing: 12) {
                            Button("View Details") {
                                showingErrorDetails = true
                            }
                            .buttonStyle(.bordered)

                            Menu {
                                Button("Retry Transient Errors Only") {
                                    Task {
                                        await viewModel.retryFailedAssignments(selective: true)
                                    }
                                }
                                Button("Retry All Failed") {
                                    Task {
                                        await viewModel.retryFailedAssignments(selective: false)
                                    }
                                }
                            } label: {
                                Label("Retry Failed", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                            .help("Retry failed assignments with exponential backoff")
                        }
                    }

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Show cancel during processing, but disable during verification
                Button("Cancel") {
                    viewModel.cancelAssignment()
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.progress?.isVerifying ?? false)
            }
        }
        .padding(40)
        .frame(width: 500, height: viewModel.failedAssignments.isEmpty ? 350 : 450)
        .sheet(isPresented: $showingErrorDetails) {
            AssignmentErrorDetailsView(failedAssignments: viewModel.failedAssignments)
        }
    }
}

// MARK: - Error Details View
struct AssignmentErrorDetailsView: View {
    let failedAssignments: [Assignment]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @State private var searchText = ""

    var filteredAssignments: [Assignment] {
        if searchText.isEmpty {
            return failedAssignments
        } else {
            return failedAssignments.filter {
                $0.applicationName.localizedCaseInsensitiveContains(searchText) ||
                $0.groupName.localizedCaseInsensitiveContains(searchText) ||
                ($0.errorMessage ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    // Helper to get remediation info based on error category
    private func getRemediationInfo(for category: String?) -> (suggestion: String, helpURL: String?, canRetry: Bool) {
        switch category {
        case "permission":
            return (
                "Contact your Azure AD administrator to grant the required Microsoft Graph permissions:\n• DeviceManagementApps.ReadWrite.All\n• Group.Read.All",
                "https://learn.microsoft.com/en-us/graph/permissions-reference",
                false
            )
        case "validation":
            return (
                "Review the assignment configuration and ensure all required fields are valid. Verify that the app and group IDs exist in your tenant.",
                "https://learn.microsoft.com/en-us/mem/intune/apps/apps-deploy",
                false
            )
        case "rateLimit":
            return (
                "Microsoft Graph is rate limiting requests. Wait a few minutes and retry the operation. Consider reducing batch size for large operations.",
                "https://learn.microsoft.com/en-us/graph/throttling",
                true
            )
        case "network":
            return (
                "Network or server error occurred. Check your internet connection and verify Microsoft Graph service status. This error is usually temporary.",
                "https://status.azure.com/",
                true
            )
        default:
            return (
                "An unexpected error occurred. Review the error message for details. Try retrying the assignment or contact support if the issue persists.",
                "https://learn.microsoft.com/en-us/mem/intune/fundamentals/get-support",
                true
            )
        }
    }

    var body: some View {
        VStack {
            HStack {
                Text("Failed Assignments")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()

            // Error summary
            let errorGroups = Dictionary(grouping: failedAssignments) { $0.errorMessage ?? "Unknown error" }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(Array(errorGroups.keys.sorted()), id: \.self) { errorType in
                        VStack {
                            Text("\(errorGroups[errorType]?.count ?? 0)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text(errorType)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(minWidth: 100)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }

            // Remediation summary by category
            if !filteredAssignments.isEmpty {
                let errorsByCategory = Dictionary(grouping: filteredAssignments) { $0.errorCategory ?? "unknown" }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(errorsByCategory.keys.sorted()), id: \.self) { category in
                            RemediationCard(
                                category: category,
                                count: errorsByCategory[category]?.count ?? 0,
                                remediation: getRemediationInfo(for: category),
                                onFixPermissions: {
                                    // Navigate to Settings tab
                                    appState.selectedTab = .settings
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
            }

            // Detailed list
            List(filteredAssignments) { assignment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(assignment.applicationName)
                                .font(.headline)
                            Text("→ \(assignment.groupName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }

                    if let error = assignment.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 2)
                    }

                    if assignment.retryCount > 0 {
                        Text("Retry attempts: \(assignment.retryCount)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .searchable(text: $searchText, prompt: "Search failed assignments")
        }
        .frame(width: 600, height: 500)
        .platformGlassBackground()
    }
}

// MARK: - Assignment Log View
struct AssignmentLogView: View {
    let logs: [AssignmentService.AssignmentLogEntry]
    @State private var filterLevel: AssignmentService.AssignmentLogEntry.LogLevel?
    @State private var searchText = ""
    @State private var autoScroll = true

    private var filteredLogs: [AssignmentService.AssignmentLogEntry] {
        var filtered = logs

        if let level = filterLevel {
            filtered = filtered.filter { $0.level == level }
        }

        if !searchText.isEmpty {
            filtered = filtered.filter { entry in
                entry.message.localizedCaseInsensitiveContains(searchText) ||
                entry.appName?.localizedCaseInsensitiveContains(searchText) == true ||
                entry.groupName?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return filtered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with filters
            HStack {
                Text("Activity Log")
                    .font(.headline)

                Spacer()

                // Level filter
                Menu {
                    Button("All") {
                        filterLevel = nil
                    }
                    Divider()
                    ForEach([AssignmentService.AssignmentLogEntry.LogLevel.info, .success, .warning, .error], id: \.self) { level in
                        Button(action: {
                            filterLevel = level
                        }) {
                            HStack {
                                if filterLevel == level {
                                    Image(systemName: "checkmark")
                                }
                                Image(systemName: level.icon)
                                Text(level.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.caption)
                        Text(filterLevel?.rawValue ?? "All")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)

                // Auto-scroll toggle
                Toggle(isOn: $autoScroll) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .help("Auto-scroll to latest")
            }

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filteredLogs) { entry in
                            LogEntryRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 200)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
                .onChange(of: logs.count) { _ in
                    if autoScroll, let lastLog = filteredLogs.last {
                        withAnimation {
                            proxy.scrollTo(lastLog.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.caption)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
    }
}

// MARK: - Log Entry Row
struct LogEntryRow: View {
    let entry: AssignmentService.AssignmentLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(entry.timestamp.formatted(date: .omitted, time: .standard))
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .leading)

            // Level icon
            Image(systemName: entry.level.icon)
                .foregroundColor(entry.level.color)
                .font(.caption)
                .frame(width: 16)

            // Message
            VStack(alignment: .leading, spacing: 2) {
                if let appName = entry.appName, let groupName = entry.groupName {
                    Text("\(appName) → \(groupName)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                Text(entry.message)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Per-App Progress Section
struct PerAppProgressSection: View {
    let perAppProgress: [String: AssignmentService.AppProgress]

    private var sortedApps: [AssignmentService.AppProgress] {
        perAppProgress.values.sorted { $0.appName < $1.appName }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per-Application Progress")
                .font(.headline)

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(sortedApps) { appProgress in
                        PerAppProgressRow(appProgress: appProgress)
                    }
                }
            }
            .frame(maxHeight: 200)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
}

// MARK: - Per-App Progress Row
struct PerAppProgressRow: View {
    let appProgress: AssignmentService.AppProgress

    private var statusColor: Color {
        switch appProgress.status {
        case .pending: return .gray
        case .processing: return .blue
        case .completed: return appProgress.groupsFailed == 0 ? .green : .orange
        case .failed: return .red
        }
    }

    private var statusIcon: String {
        switch appProgress.status {
        case .pending: return "circle"
        case .processing: return "arrow.triangle.2.circlepath"
        case .completed: return appProgress.groupsFailed == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Status icon
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.caption)

                // App name
                Text(appProgress.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)

                Spacer()

                // Progress stats
                HStack(spacing: 4) {
                    if appProgress.groupsCompleted > 0 {
                        Text("\(appProgress.groupsCompleted)")
                            .foregroundColor(.green)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    if appProgress.groupsFailed > 0 {
                        Text("\(appProgress.groupsFailed)")
                            .foregroundColor(.red)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    Text("/ \(appProgress.groupsTotal)")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }

            // Progress bar
            ProgressView(value: appProgress.percentComplete, total: 100)
                .progressViewStyle(.linear)
                .frame(height: 6)
                .tint(statusColor)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Remediation Card
struct RemediationCard: View {
    let category: String
    let count: Int
    let remediation: (suggestion: String, helpURL: String?, canRetry: Bool)
    let onFixPermissions: () -> Void

    private var categoryInfo: (name: String, icon: String, color: Color) {
        switch category {
        case "permission":
            return ("Permission", "lock.shield", .red)
        case "validation":
            return ("Validation", "exclamationmark.triangle", .orange)
        case "rateLimit":
            return ("Rate Limit", "clock", .yellow)
        case "network":
            return ("Network", "wifi.slash", .blue)
        default:
            return ("Unknown", "questionmark.circle", .gray)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: categoryInfo.icon)
                    .foregroundColor(categoryInfo.color)
                VStack(alignment: .leading) {
                    Text(categoryInfo.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("\(count) error\(count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Remediation suggestion
            Text("What to do next:")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Text(remediation.suggestion)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Action buttons
            HStack(spacing: 8) {
                if category == "permission" {
                    Button(action: onFixPermissions) {
                        Label("Fix Permissions", systemImage: "gear")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                }

                if let helpURL = remediation.helpURL, let url = URL(string: helpURL) {
                    Link(destination: url) {
                        Label("Help", systemImage: "questionmark.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .frame(width: 280)
        .background(categoryInfo.color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(categoryInfo.color.opacity(0.3), lineWidth: 1)
        )
    }
}