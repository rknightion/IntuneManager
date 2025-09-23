import SwiftUI

struct CacheStatusView: View {
    @StateObject private var cacheManager = CacheManager.shared
    @State private var isRefreshingAll = false
    @State private var refreshingPolicy: CachePolicy?
    @State private var showingClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection

            Divider()

            // Cache Entries
            List {
                ForEach(CachePolicy.allCases, id: \.self) { policy in
                    CacheEntryRow(
                        policy: policy,
                        metadata: cacheManager.getMetadata(for: policy),
                        isRefreshing: refreshingPolicy == policy,
                        onRefresh: { await refreshCache(policy) }
                    )
                }
            }
            .listStyle(.inset)

            Divider()

            // Footer Controls
            footerControls
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            cacheManager.loadMetadata()
        }
        .alert("Clear All Caches", isPresented: $showingClearConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Only", role: .destructive) {
                clearAllCaches()
            }
            Button("Clear & Refresh", role: .destructive) {
                Task {
                    clearAllCaches()
                    await refreshAll()
                }
            }
        } message: {
            Text("This will remove all cached data from your device. Choose 'Clear & Refresh' to immediately fetch fresh data from Microsoft Intune, or 'Clear Only' to clear the cache and fetch data on demand.")
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache Status")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        Image(systemName: cacheManager.getHealthStatus().icon)
                            .foregroundColor(Color.systemColor(named: cacheManager.getHealthStatus().color))
                        Text(cacheManager.getHealthStatus().description)
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                }

                Spacer()

                // Health Indicator
                CacheHealthIndicator(status: cacheManager.getHealthStatus())
            }
            .padding(.horizontal)

            // Statistics
            CacheStatistics(cacheManager: cacheManager)
        }
        .padding(.vertical)
        .background(Color.gray.opacity(0.05))
    }

    private var footerControls: some View {
        HStack {
            Toggle("Background Refresh", isOn: $cacheManager.backgroundRefreshEnabled)
                .toggleStyle(.switch)
                .help("Automatically refresh caches in the background when they expire")

            Spacer()

            Button(action: { showingClearConfirmation = true }) {
                Label("Clear Cache", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .help("Remove all cached data")

            Button(action: { Task { await refreshAll() } }) {
                Label(isRefreshingAll ? "Refreshing..." : "Refresh Data",
                      systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRefreshingAll)
            .help("Fetch fresh data from Microsoft Intune")
        }
        .padding()
    }

    private func refreshAll() async {
        isRefreshingAll = true
        await cacheManager.refreshAll()
        isRefreshingAll = false
        cacheManager.loadMetadata()
    }

    private func refreshCache(_ policy: CachePolicy) async {
        refreshingPolicy = policy
        do {
            try await cacheManager.refresh(policy: policy)
        } catch {
            Logger.shared.error("Failed to refresh \(policy.rawValue): \(error)")
        }
        refreshingPolicy = nil
        cacheManager.loadMetadata()
    }

    private func clearAllCaches() {
        // Use the unified clear method from CacheManager
        cacheManager.clearAllCaches()

        // Force reload metadata to reflect cleared state
        cacheManager.loadMetadata()
    }
}

// MARK: - Supporting Views

struct CacheHealthIndicator: View {
    let status: CacheHealthStatus

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color.systemColor(named: status.color).opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: status.icon)
                    .font(.title)
                    .foregroundColor(Color.systemColor(named: status.color))
            }

            Text(status.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct CacheStatistics: View {
    @ObservedObject var cacheManager: CacheManager

    var body: some View {
        let stats = cacheManager.getCacheSize()

        HStack(spacing: 20) {
            CacheStatCard(
                title: "Total Records",
                value: "\(stats.totalRecords)",
                icon: "doc.text.fill",
                color: .blue
            )

            CacheStatCard(
                title: "Cache Entries",
                value: "\(stats.cacheEntries)",
                icon: "cylinder.fill",
                color: .green
            )

            CacheStatCard(
                title: "Average Age",
                value: stats.formattedAverageAge,
                icon: "clock.fill",
                color: .orange
            )

            CacheStatCard(
                title: "Expired",
                value: "\(stats.expiredCount)",
                icon: "exclamationmark.triangle.fill",
                color: .red
            )

            CacheStatCard(
                title: "Stale",
                value: "\(stats.staleCount)",
                icon: "exclamationmark.circle.fill",
                color: .yellow
            )
        }
        .padding(.horizontal)
    }
}

struct CacheStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct CacheEntryRow: View {
    let policy: CachePolicy
    let metadata: CacheMetadata?
    let isRefreshing: Bool
    let onRefresh: () async -> Void

    @State private var showingDetails = false

    var body: some View {
        HStack {
            // Icon and Name
            Label(policy.displayName, systemImage: policy.icon)
                .font(.body)
                .frame(width: 180, alignment: .leading)

            // Status
            if let metadata = metadata {
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(for: metadata))
                        .frame(width: 8, height: 8)

                    Text(statusText(for: metadata))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 100, alignment: .leading)

                // Record Count
                Text("\(metadata.recordCount) records")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 100, alignment: .trailing)

                // Last Updated
                Text(metadata.lastFetch.formatted(.relative(presentation: .named)))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .trailing)

                // TTL
                Text(formatTTL(metadata.remainingTTL))
                    .font(.caption)
                    .foregroundColor(metadata.isExpired ? .red : .secondary)
                    .frame(width: 80, alignment: .trailing)
            } else {
                Text("Not cached")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if metadata != nil {
                    Button(action: { showingDetails = true }) {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.plain)
                    .help("View Details")
                }

                Button(action: {
                    Task { await onRefresh() }
                }) {
                    if isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
                .help("Refresh Cache")
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingDetails) {
            if let metadata = metadata {
                CacheDetailView(policy: policy, metadata: metadata)
            }
        }
    }

    private func statusColor(for metadata: CacheMetadata) -> Color {
        if metadata.isExpired {
            return .red
        } else if metadata.isStale {
            return .orange
        } else if metadata.remainingTTL < 60 {
            return .yellow
        } else {
            return .green
        }
    }

    private func statusText(for metadata: CacheMetadata) -> String {
        if metadata.isExpired {
            return "Expired"
        } else if metadata.isStale {
            return "Stale"
        } else if metadata.remainingTTL < 60 {
            return "Expiring soon"
        } else {
            return "Fresh"
        }
    }

    private func formatTTL(_ seconds: TimeInterval) -> String {
        if seconds <= 0 {
            return "Expired"
        }

        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds < 3600 ? [.minute, .second] : [.hour, .minute]
        return formatter.string(from: seconds) ?? "Unknown"
    }
}

struct CacheDetailView: View {
    let policy: CachePolicy
    let metadata: CacheMetadata
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Label(policy.displayName, systemImage: policy.icon)
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            // Details Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                DetailItem(title: "Entity Type", value: metadata.entityType)
                DetailItem(title: "Cache ID", value: metadata.id)
                DetailItem(title: "Record Count", value: "\(metadata.recordCount)")
                DetailItem(title: "Last Fetch", value: metadata.lastFetch.formatted())
                DetailItem(title: "Expires At", value: metadata.expiresAt.formatted())
                DetailItem(title: "Age", value: formatAge(metadata.age))
                DetailItem(title: "Remaining TTL", value: formatAge(metadata.remainingTTL))
                DetailItem(title: "Is Stale", value: metadata.isStale ? "Yes" : "No")
                DetailItem(title: "Is Expired", value: metadata.isExpired ? "Yes" : "No")
                DetailItem(title: "TTL Policy", value: formatAge(policy.ttlSeconds))
                if let eTag = metadata.eTag {
                    DetailItem(title: "ETag", value: eTag)
                }
                if let lastModified = metadata.lastModified {
                    DetailItem(title: "Last Modified", value: lastModified.formatted())
                }
            }

            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
    }

    private func formatAge(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds) ?? "Unknown"
    }
}

struct DetailItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}