import Foundation
import Combine

@MainActor
final class AssignmentFilterService: ObservableObject {
    static let shared = AssignmentFilterService()

    @Published private(set) var filters: [AssignmentFilter] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let apiClient = GraphAPIClient.shared
    private let dataStore = LocalDataStore.shared

    private init() {
        filters = dataStore.fetchAssignmentFilters()
    }

    /// Returns all cached filters. Triggers a fetch if cache is empty.
    func getFilters(forceRefresh: Bool = false) async -> [AssignmentFilter] {
        if filters.isEmpty || forceRefresh {
            await fetchFilters(forceRefresh: forceRefresh)
        }
        return filters
    }

    /// Fetches assignment filters from Microsoft Graph and updates the cache.
    func fetchFilters(forceRefresh: Bool = false) async {
        if isLoading { return }
        if !forceRefresh, !filters.isEmpty { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let response: AssignmentFilterResponse = try await apiClient.getModel("/deviceManagement/assignmentFilters")
            let sorted = response.value.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            dataStore.replaceAssignmentFilters(with: sorted)
            filters = sorted
            error = nil
        } catch {
            self.error = error
            Logger.shared.error("Failed to fetch assignment filters: \(error.localizedDescription)", category: .network)
        }
    }

    func filter(withId id: String?) -> AssignmentFilter? {
        guard let id else { return nil }
        return filters.first { $0.id == id }
    }

    func filters(for appType: Application.AppType) -> [AssignmentFilter] {
        let supportedPlatforms = platforms(for: appType)

        guard !supportedPlatforms.isEmpty else {
            return filters
        }

        return filters.filter { filter in
            supportedPlatforms.contains(filter.platform)
        }
    }

    func filters(for platforms: Set<AssignmentFilter.FilterPlatform>) -> [AssignmentFilter] {
        guard !platforms.isEmpty else { return filters }
        return filters.filter { platforms.contains($0.platform) }
    }

    private func platforms(for appType: Application.AppType) -> Set<AssignmentFilter.FilterPlatform> {
        switch appType {
        case .iOS, .iosLobApp, .iosVppApp, .iosStoreApp, .managedIOSStoreApp:
            return [.ios]
        case .macOS, .macOSLobApp, .macOSVppApp, .macOSPkgApp, .macOSDmgApp, .managedMacOSStoreApp, .macOSOfficeSuiteApp, .macOSMicrosoftDefenderApp:
            return [.macOS]
        case .androidStoreApp, .androidManagedStoreApp:
            return [.android, .androidForWork]
        case .windowsMobileMSI, .winAppX, .win32LobApp, .microsoftEdgeApp, .microsoftStoreForBusinessApp, .windowsUniversalAppX, .winGetApp, .officeSuiteApp, .windowsWebApp, .win32CatalogApp, .microsoftDefenderForEndpoint:
            return [.windows10AndLater, .windows81AndLater]
        default:
            return []
        }
    }
}
