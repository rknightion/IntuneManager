import Foundation
import Combine

// MARK: - Helper Types for ApplicationService

fileprivate struct AssignmentsResponse: Decodable, Sendable {
    let value: [AppAssignment]
}

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
        Logger.shared.info("Fetching applications (forceRefresh: \(forceRefresh))", category: .data)

        if !forceRefresh {
            let cached = dataStore.fetchApplications()
            if !cached.isEmpty {
                Logger.shared.info("Using cached applications: \(cached.count) items", category: .data)
                applications = cached
                return cached
            }
            Logger.shared.info("No cached applications found, fetching from API", category: .data)
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let endpoint = "/deviceAppManagement/mobileApps"
            let parameters = [
                "$expand": "assignments",
                "$orderby": "displayName",
                "$top": "999"  // Request maximum apps per page to reduce pagination
                // Removed filter - now fetching ALL apps to enable assignment of unassigned apps
            ]

            Logger.shared.info("Requesting applications from Graph API with pagination support...", category: .network)
            Logger.shared.info("API endpoint: \(endpoint)", category: .network)
            Logger.shared.info("Parameters: \(parameters)", category: .network)

            let fetchedApps: [Application] = try await apiClient.getAllPagesForModels(endpoint, parameters: parameters)
            Logger.shared.info("Received \(fetchedApps.count) total apps from API after pagination", category: .data)

            // Log app type distribution for debugging
            let appTypeGroups = Dictionary(grouping: fetchedApps, by: { $0.appType })
            Logger.shared.info("=== App Type Distribution ===", category: .data)
            for (type, apps) in appTypeGroups.sorted(by: { $0.value.count > $1.value.count }) {
                Logger.shared.info("  \(type.displayName) (\(type.rawValue)): \(apps.count) apps", category: .data)
                // Log first few app names of each type for debugging
                let sampleApps = apps.prefix(3).map { $0.displayName }.joined(separator: ", ")
                Logger.shared.debug("    Sample: \(sampleApps)", category: .data)
            }
            Logger.shared.info("=== End Distribution ===", category: .data)

            // Don't filter ANY apps - show everything to the user
            // Users need to see all apps to properly manage assignments
            let filteredApps = fetchedApps

            Logger.shared.info("Total apps available: \(filteredApps.count)", category: .data)

            self.applications = filteredApps
            self.lastSync = Date()

            dataStore.replaceApplications(with: filteredApps)
            Logger.shared.info("Stored \(filteredApps.count) applications in cache", category: .data)

            return filteredApps
        } catch {
            self.error = error
            Logger.shared.error("Failed to fetch applications: \(error.localizedDescription)", category: .data)
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

        let response: AssignmentsResponse = try await apiClient.getModel(endpoint)
        return response.value
    }

    func createAssignment(appId: String, assignment: AppAssignment) async throws -> AppAssignment {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments"

        let createdAssignment: AppAssignment = try await apiClient.postModel(endpoint, body: assignment)

        Logger.shared.info("Created assignment for app \(appId) to group \(assignment.target.groupId ?? "unknown")")

        // Refresh app data
        _ = try await fetchApplication(id: appId)

        return createdAssignment
    }

    func updateAssignment(appId: String, assignmentId: String, assignment: AppAssignment) async throws -> AppAssignment {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/assignments/\(assignmentId)"

        let updatedAssignment: AppAssignment = try await apiClient.patchModel(endpoint, body: assignment)

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

        let responses: [BatchResponse<AppAssignment>] = try await apiClient.batchModels(requests)

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

        let responses: [BatchResponse<EmptyResponse>] = try await apiClient.batchModels(requests)

        let successCount = responses.filter { $0.status >= 200 && $0.status < 300 }.count

        Logger.shared.info("Deleted \(successCount) assignments in batch")

        // Refresh applications data
        _ = try await fetchApplications(forceRefresh: true)
    }

    // MARK: - Install Summary

    func fetchInstallSummary(appId: String) async throws -> Application.InstallSummary {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)/installSummary"

        let summary: Application.InstallSummary = try await apiClient.getModel(endpoint)
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
