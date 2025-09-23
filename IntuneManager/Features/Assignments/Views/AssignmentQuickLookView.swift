import SwiftUI
import Combine

struct AssignmentQuickLookView: View {
    @StateObject private var assignmentService = AssignmentService.shared
    @State private var storageSummary = StorageSummary()

    private var stats: AssignmentStatistics {
        assignmentService.getAssignmentStatistics()
    }

    var body: some View {
        VStack(spacing: 24) {
            header
            progressView
            metricsGrid
            recentList
        }
        .padding(32)
        .frame(minWidth: 420, minHeight: 520)
        .platformGlassBackground(cornerRadius: 36)
        .padding()
        .background(background)
        .onAppear {
            storageSummary = LocalDataStore.shared.summary()
        }
        .onChange(of: assignmentService.assignmentHistory) { _, _ in
            // Delay to avoid state change during view update
            DispatchQueue.main.async {
                storageSummary = LocalDataStore.shared.summary()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Assignments Overview")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(storageSummary.formatted)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var progressView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completion Rate")
                .font(.headline)

            ProgressView(value: Double(stats.completed), total: Double(max(stats.total, 1))) {
                Text("Completed \(stats.completed) of \(stats.total)")
            }
            .progressViewStyle(.linear)

            if assignmentService.isProcessing, let progress = assignmentService.currentProgress {
                Text("Currently processing: \(progress.currentOperation)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .platformGlassBackground(cornerRadius: 24)
    }

    private var metricsGrid: some View {
        HStack(spacing: 16) {
            MetricCard(title: "Completed",
                       value: stats.completed,
                       systemImage: "checkmark.circle.fill",
                       tint: .green)
            MetricCard(title: "Pending",
                       value: stats.pending,
                       systemImage: "clock.fill",
                       tint: .blue)
            MetricCard(title: "Failed",
                       value: stats.failed,
                       systemImage: "xmark.octagon.fill",
                       tint: .red)
        }
    }

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Assignments")
                .font(.headline)

            if assignmentService.assignmentHistory.isEmpty {
                Text("No assignments yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(assignmentService.assignmentHistory.prefix(6)) { assignment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(assignment.applicationName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("→ \(assignment.groupName)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                HStack {
                                    Label(assignment.status.displayName, systemImage: assignment.status.icon)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    if let completed = assignment.completedDate {
                                        Text(completed, style: .relative)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding(12)
                            .platformGlassBackground(cornerRadius: 16)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.3), Color.purple.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if #available(iOS 18, macOS 15, *) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: 120)
                    .opacity(0.35)
                    .ignoresSafeArea()
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text("\(value)")
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .platformGlassBackground(cornerRadius: 20)
    }
}
