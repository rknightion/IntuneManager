import Foundation
import SwiftData
import Combine

@MainActor
final class CacheManager: ObservableObject {
    static let shared = CacheManager()

    @Published var cacheMetadata: [CacheMetadata] = []
    @Published var isRefreshing = false
    @Published var backgroundRefreshEnabled = true

    private var modelContext: ModelContext?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupBackgroundRefresh()
    }

    func configure(with context: ModelContext) {
        modelContext = context
        loadMetadata()
    }

    // MARK: - Metadata Management

    func loadMetadata() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<CacheMetadata>(sortBy: [SortDescriptor(\.entityType)])
        cacheMetadata = (try? context.fetch(descriptor)) ?? []
    }

    func getMetadata(for policy: CachePolicy) -> CacheMetadata? {
        cacheMetadata.first { $0.entityType == policy.rawValue }
    }

    func updateMetadata(for policy: CachePolicy, recordCount: Int, eTag: String? = nil) {
        guard let context = modelContext else { return }

        if let existing = getMetadata(for: policy) {
            existing.refresh(ttlSeconds: policy.ttlSeconds, recordCount: recordCount)
            existing.eTag = eTag
        } else {
            let metadata = CacheMetadata(
                entityType: policy.rawValue,
                ttlSeconds: policy.ttlSeconds,
                recordCount: recordCount,
                eTag: eTag
            )
            context.insert(metadata)
            cacheMetadata.append(metadata)
        }

        try? context.save()
        loadMetadata()
    }

    func markStale(for policy: CachePolicy) {
        if let metadata = getMetadata(for: policy) {
            metadata.markStale()
            try? modelContext?.save()
        }
    }

    func clearMetadata(for policy: CachePolicy) {
        guard let context = modelContext,
              let metadata = getMetadata(for: policy) else { return }

        context.delete(metadata)
        try? context.save()
        loadMetadata()
    }

    func clearAllMetadata() {
        guard let context = modelContext else { return }

        for metadata in cacheMetadata {
            context.delete(metadata)
        }
        try? context.save()
        cacheMetadata.removeAll()
    }

    /// Clears all caches including both metadata and actual stored data
    func clearAllCaches() {
        // Clear all metadata
        clearAllMetadata()

        // Clear all stored data
        LocalDataStore.shared.reset()

        // Reset any in-memory caches in services
        DeviceService.shared.devices.removeAll()
        ApplicationService.shared.applications.removeAll()
        GroupService.shared.groups.removeAll()
        AssignmentService.shared.activeAssignments.removeAll()

        Logger.shared.info("All caches and data cleared", category: .data)
    }

    // MARK: - Cache Validity Checks

    func shouldRefresh(for policy: CachePolicy, forceRefresh: Bool = false) -> Bool {
        if forceRefresh { return true }

        guard let metadata = getMetadata(for: policy) else {
            return true // No metadata, needs initial fetch
        }

        return metadata.isExpired || metadata.isStale
    }

    func canUseCache(for policy: CachePolicy) -> Bool {
        guard let metadata = getMetadata(for: policy) else {
            return false
        }

        return !metadata.isExpired && !metadata.isStale && metadata.recordCount > 0
    }

    // MARK: - Background Refresh

    private func setupBackgroundRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkForStaleCache()
            }
        }
    }

    private func checkForStaleCache() async {
        guard backgroundRefreshEnabled else { return }

        for metadata in cacheMetadata {
            if metadata.isExpired || metadata.remainingTTL < 60 {
                if let policy = CachePolicy(rawValue: metadata.entityType) {
                    await refreshCacheInBackground(for: policy)
                }
            }
        }
    }

    private func refreshCacheInBackground(for policy: CachePolicy) async {
        Logger.shared.debug("Background refresh starting for \(policy.rawValue)", category: .data)

        switch policy {
        case .devices:
            _ = try? await DeviceService.shared.fetchDevices(forceRefresh: true)
        case .applications:
            _ = try? await ApplicationService.shared.fetchApplications(forceRefresh: true)
        case .groups:
            _ = try? await GroupService.shared.fetchGroups(forceRefresh: true)
        case .assignments:
            // Assignments are handled differently
            break
        case .compliancePolicies, .configurationProfiles, .auditLogs, .userProfiles:
            // To be implemented when these services are added
            break
        }
    }

    // MARK: - Cache Statistics

    func getCacheSize() -> CacheSizeInfo {
        var totalRecords = 0
        var totalAge: TimeInterval = 0
        var expiredCount = 0
        var staleCount = 0

        for metadata in cacheMetadata {
            totalRecords += metadata.recordCount
            totalAge += metadata.age
            if metadata.isExpired { expiredCount += 1 }
            if metadata.isStale { staleCount += 1 }
        }

        let averageAge = cacheMetadata.isEmpty ? 0 : totalAge / Double(cacheMetadata.count)

        return CacheSizeInfo(
            totalRecords: totalRecords,
            cacheEntries: cacheMetadata.count,
            averageAge: averageAge,
            expiredCount: expiredCount,
            staleCount: staleCount
        )
    }

    func getHealthStatus() -> CacheHealthStatus {
        let stats = getCacheSize()

        if stats.expiredCount > stats.cacheEntries / 2 {
            return .poor
        } else if stats.staleCount > stats.cacheEntries / 3 {
            return .fair
        } else if stats.expiredCount == 0 && stats.staleCount == 0 {
            return .excellent
        } else {
            return .good
        }
    }

    // MARK: - Smart Invalidation

    func invalidateRelatedCaches(for policy: CachePolicy) {
        switch policy {
        case .devices:
            // Device changes might affect assignments
            markStale(for: .assignments)
        case .applications:
            // App changes might affect assignments
            markStale(for: .assignments)
        case .groups:
            // Group changes might affect devices and assignments
            markStale(for: .devices)
            markStale(for: .assignments)
        case .assignments:
            // Assignment changes might affect apps and devices
            markStale(for: .applications)
            markStale(for: .devices)
        default:
            break
        }
    }

    // MARK: - Manual Refresh

    func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await SyncService.shared.performFullSync()
            Logger.shared.info("Manual cache refresh completed", category: .data)
        } catch {
            Logger.shared.error("Manual cache refresh failed: \(error)", category: .data)
        }
    }

    func refresh(policy: CachePolicy) async throws {
        isRefreshing = true
        defer { isRefreshing = false }

        switch policy {
        case .devices:
            _ = try await DeviceService.shared.fetchDevices(forceRefresh: true)
        case .applications:
            _ = try await ApplicationService.shared.fetchApplications(forceRefresh: true)
        case .groups:
            _ = try await GroupService.shared.fetchGroups(forceRefresh: true)
        default:
            Logger.shared.warning("Refresh not implemented for \(policy.rawValue)", category: .data)
        }
    }
}

// MARK: - Supporting Types

struct CacheSizeInfo {
    let totalRecords: Int
    let cacheEntries: Int
    let averageAge: TimeInterval
    let expiredCount: Int
    let staleCount: Int

    var formattedAverageAge: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute]
        return formatter.string(from: averageAge) ?? "Unknown"
    }
}

enum CacheHealthStatus {
    case excellent
    case good
    case fair
    case poor

    var color: String {
        switch self {
        case .excellent: return "systemGreen"
        case .good: return "systemBlue"
        case .fair: return "systemOrange"
        case .poor: return "systemRed"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "checkmark.circle.fill"
        case .good: return "checkmark.circle"
        case .fair: return "exclamationmark.triangle"
        case .poor: return "xmark.octagon"
        }
    }

    var description: String {
        switch self {
        case .excellent: return "All caches fresh"
        case .good: return "Most caches up-to-date"
        case .fair: return "Some caches need refresh"
        case .poor: return "Many caches expired"
        }
    }
}