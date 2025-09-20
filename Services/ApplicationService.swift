import Foundation
import Combine

@MainActor
final class ApplicationService: ObservableObject {
    static let shared = ApplicationService()

    @Published var applications: [Application] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastSync: Date?

    private let apiClient = GraphAPIClient.shared
    private let dataStore = LocalDataStore.shared

    private init() {
        applications = dataStore.fetchApplications()
    }

    // MARK: - Public Methods

    func fetchApplications(forceRefresh: Bool = false) async throws -> [Application] {
        if !forceRefresh {
            let cached = dataStore.fetchApplications()
            if !cached.isEmpty {
                applications = cached
                return cached
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let endpoint = "/deviceAppManagement/mobileApps"
            let parameters = [
                "$expand": "assignments",
                "$orderby": "displayName",
                "$filter": "isAssigned eq true"
            ]

            let fetchedApps: [Application] = try await apiClient.getAllPagesForModels(endpoint, parameters: parameters)

            // Filter for macOS, iOS, and iPadOS apps
            let filteredApps = fetchedApps.filter { app in
                switch app.appType {
                case .macOS, .iOS, .macOSLobApp, .iosLobApp, .iosVppApp, .macOSVppApp,
                     .managedIOSStoreApp, .managedMacOSStoreApp, .macOSOfficeSuiteApp,
                     .macOSPkgApp, .macOSDmgApp:
                    return true
                default:
                    return false
                }
            }

            self.applications = filteredApps
            self.lastSync = Date()

            dataStore.replaceApplications(with: filteredApps)

            Logger.shared.info("Fetched \(filteredApps.count) applications from Graph API")

            return filteredApps
        } catch {
            self.error = error
            Logger.shared.error("Failed to fetch applications: \(error)")
            throw error
        }
    }

    func fetchApplication(id: String) async throws -> Application {
        let endpoint = "/deviceAppManagement/mobileApps/\(id)"
        let parameters = ["$expand": "assignments"]

        let app: Application = try await apiClient.getModel(endpoint, parameters: parameters)
        return app
    }

    func searchApplications(query: String) -> [Application] {
        guard !query.isEmpty else { return applications }

        return applications.filter { app in
            app.displayName.localizedCaseInsensitiveContains(query) ||
            app.appDescription?.localizedCaseInsensitiveContains(query) == true ||
            app.publisher?.localizedCaseInsensitiveContains(query) == true ||
            app.bundleId?.localizedCaseInsensitiveContains(query) == true
        }
    }

    func filterApplications(by criteria: AppFilterCriteria) -> [Application] {
        var filtered = applications

        if let appType = criteria.appType {
            filtered = filtered.filter { $0.appType == appType }
        }

        if let publishingState = criteria.publishingState {
            filtered = filtered.filter { $0.publishingState == publishingState }
        }

        if criteria.onlyFeatured {
            filtered = filtered.filter { $0.isFeatured }
        }

        if criteria.hasAssignments {
            filtered = filtered.filter { ($0.assignments?.count ?? 0) > 0 }
        }

        return filtered
    }

    // MARK: - Assignment Operations

    func getApplicationAssignments(appId: String) async throws -> [AppAssignment] {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments"

        struct AssignmentsResponse: Decodable, Sendable {
            let value: [AppAssignment]
        }

        let response: AssignmentsResponse = try await apiClient.get(endpoint)
        return response.value
    }

    func createAssignment(appId: String, assignment: AppAssignment) async throws -> AppAssignment {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments"

        let createdAssignment: AppAssignment = try await apiClient.post(endpoint, body: assignment)

        Logger.shared.info("Created assignment for app \(appId) to group \(assignment.target.groupId ?? "unknown")")

        // Refresh app data
        _ = try await fetchApplication(id: appId)

        return createdAssignment
    }

    func updateAssignment(appId: String, assignmentId: String, assignment: AppAssignment) async throws -> AppAssignment {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments/\(assignmentId)"

        let updatedAssignment: AppAssignment = try await apiClient.patch(endpoint, body: assignment)

        Logger.shared.info("Updated assignment \(assignmentId) for app \(appId)")

        return updatedAssignment
    }

    func deleteAssignment(appId: String, assignmentId: String) async throws {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments/\(assignmentId)"

        try await apiClient.delete(endpoint)

        Logger.shared.info("Deleted assignment \(assignmentId) for app \(appId)")

        // Refresh app data
        _ = try await fetchApplication(id: appId)
    }

    // MARK: - Batch Assignment Operations

    func createBatchAssignments(_ assignments: [(appId: String, assignment: AppAssignment)]) async throws -> [AppAssignment] {
        let requests = assignments.map { appId, assignment in
            BatchRequest(
                method: "POST",
                url: "/deviceAppManagement/mobileApps/\(appId)/assignments",
                body: assignment
            )
        }

        let responses: [BatchResponse<AppAssignment>] = try await apiClient.batch(requests)

        let successfulAssignments = responses.compactMap { response in
            response.status >= 200 && response.status < 300 ? response.body : nil
        }

        Logger.shared.info("Created \(successfulAssignments.count) assignments in batch")

        // Refresh applications data
        _ = try await fetchApplications(forceRefresh: true)

        return successfulAssignments
    }

    func deleteBatchAssignments(_ assignments: [(appId: String, assignmentId: String)]) async throws {
        let requests = assignments.map { appId, assignmentId in
            BatchRequest(
                method: "DELETE",
                url: "/deviceAppManagement/mobileApps/\(appId)/assignments/\(assignmentId)"
            )
        }

        let responses: [BatchResponse<EmptyResponse>] = try await apiClient.batch(requests)

        let successCount = responses.filter { $0.status >= 200 && $0.status < 300 }.count

        Logger.shared.info("Deleted \(successCount) assignments in batch")

        // Refresh applications data
        _ = try await fetchApplications(forceRefresh: true)
    }

    // MARK: - Install Summary

    func fetchInstallSummary(appId: String) async throws -> Application.InstallSummary {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/installSummary"

        let summary: Application.InstallSummary = try await apiClient.get(endpoint)
        return summary
    }

    // MARK: - Private Methods

    func hydrateFromStore() {
        let cachedApps = dataStore.fetchApplications()
        if !cachedApps.isEmpty {
            applications = cachedApps
        }
    }
}

// MARK: - Supporting Types

struct AppFilterCriteria {
    var appType: Application.AppType?
    var publishingState: Application.PublishingState?
    var onlyFeatured: Bool = false
    var hasAssignments: Bool = false
    var searchQuery: String?
}
