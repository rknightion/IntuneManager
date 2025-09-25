import Foundation
import Combine

// MARK: - Notifications
extension Notification.Name {
    static let applicationDeleted = Notification.Name("applicationDeleted")
    static let applicationsDeleted = Notification.Name("applicationsDeleted")
}

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
    private let cacheManager = CacheManager.shared

    private init() {
        applications = dataStore.fetchApplications()
    }

    // MARK: - Public Methods

    func fetchApplications(forceRefresh: Bool = false) async throws -> [Application] {
        Logger.shared.info("Fetching applications (forceRefresh: \(forceRefresh))", category: .data)

        // Use CacheManager to determine if we should use cache
        if cacheManager.canUseCache(for: .applications) && !forceRefresh {
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

            // Update the data store first to maintain context consistency
            dataStore.replaceApplications(with: filteredApps)

            // Now update the in-memory collection with fresh data from the store
            // This ensures we're working with models attached to the current context
            self.applications = dataStore.fetchApplications()
            self.lastSync = Date()

            cacheManager.updateMetadata(for: .applications, recordCount: filteredApps.count)
            Logger.shared.info("Stored \(filteredApps.count) applications in cache", category: .data)

            return filteredApps
        } catch {
            self.error = error
            // Provide more helpful error messages for rate limiting
            if let graphError = error as? GraphAPIError {
                switch graphError {
                case .rateLimited(let retryAfter):
                    Logger.shared.warning("Rate limited when fetching applications. Retry after: \(retryAfter ?? "unknown") seconds", category: .data)
                default:
                    Logger.shared.error("Failed to fetch applications: \(error.localizedDescription)", category: .data)
                }
            } else {
                Logger.shared.error("Failed to fetch applications: \(error.localizedDescription)", category: .data)
            }
            throw error
        }
    }

    func fetchApplication(id: String) async throws -> Application {
        let endpoint = "/deviceAppManagement/mobileApps/\(id)"
        let parameters = ["$expand": "assignments"]

        do {
            let app: Application = try await apiClient.getModel(endpoint, parameters: parameters)
            Logger.shared.debug("Successfully fetched application: \(app.displayName)", category: .data)
            return app
        } catch let decodingError as DecodingError {
            // Log detailed decoding error for debugging
            switch decodingError {
            case .keyNotFound(let key, let context):
                Logger.shared.error("Missing key '\(key.stringValue)' at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .data)
            case .typeMismatch(let type, let context):
                Logger.shared.error("Type mismatch for type '\(type)' at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .data)
            case .valueNotFound(let type, let context):
                Logger.shared.error("Value not found for type '\(type)' at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .data)
            case .dataCorrupted(let context):
                Logger.shared.error("Data corrupted at: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .data)
            @unknown default:
                Logger.shared.error("Unknown decoding error: \(decodingError)", category: .data)
            }
            throw decodingError
        } catch {
            Logger.shared.error("Failed to fetch application details: \(error.localizedDescription)", category: .data)
            throw error
        }
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

    // MARK: - Delete Applications

    func deleteApplication(_ appId: String) async throws {
        let endpoint = "/deviceAppManagement/mobileApps/\(appId)"

        try await apiClient.delete(endpoint)

        Logger.shared.info("Deleted application \(appId)")

        // Remove from local cache
        // Create a new array to avoid modifying detached models
        let remainingApps = applications.filter { $0.id != appId }
        applications = remainingApps
        dataStore.replaceApplications(with: remainingApps)

        // Post notification for UI updates
        NotificationCenter.default.post(name: .applicationDeleted, object: appId)
    }

    func deleteBatchApplications(_ appIds: [String]) async throws -> (successful: [String], failed: [(id: String, error: String)]) {
        guard !appIds.isEmpty else {
            return ([], [])
        }

        Logger.shared.info("Starting batch deletion of \(appIds.count) applications")

        // Create batch requests - max 20 per batch
        let batches = appIds.chunked(into: 20)
        var allSuccessful: [String] = []
        var allFailed: [(id: String, error: String)] = []

        for batch in batches {
            let requests = batch.map { appId in
                BatchRequest(
                    method: "DELETE",
                    url: "/deviceAppManagement/mobileApps/\(appId)"
                )
            }

            // Use a response type that can capture error details
            struct DeleteErrorResponse: Decodable, Sendable {
                let error: ErrorDetail?

                struct ErrorDetail: Decodable {
                    let code: String?
                    let message: String?
                    let innerError: InnerError?

                    struct InnerError: Decodable {
                        let message: String?
                        let code: String?
                        let date: String?
                        let requestId: String?
                        let clientRequestId: String?
                    }
                }
            }

            let responses: [BatchResponse<DeleteErrorResponse>] = try await apiClient.batchModels(requests)

            for (index, response) in responses.enumerated() {
                let appId = batch[index]

                if response.status >= 200 && response.status < 300 {
                    allSuccessful.append(appId)
                    Logger.shared.info("Successfully deleted application \(appId)")
                } else {
                    // Extract error details from the response
                    var errorMessage = "HTTP \(response.status)"

                    if let errorBody = response.body,
                       let error = errorBody.error {
                        if let message = error.message {
                            errorMessage = message

                            // Common error patterns
                            if message.lowercased().contains("vpp") || message.lowercased().contains("license") {
                                errorMessage = "VPP licenses still assigned. Remove all VPP assignments first."
                            } else if message.lowercased().contains("permission") || response.status == 403 {
                                errorMessage = "Insufficient permissions to delete this application"
                            } else if message.lowercased().contains("not found") || response.status == 404 {
                                errorMessage = "Application not found or already deleted"
                            } else if response.status == 409 {
                                errorMessage = "Conflict: \(message)"
                            }
                        } else if let code = error.code {
                            errorMessage = "Error code: \(code)"
                        }

                        // Log detailed error information
                        Logger.shared.error("""
                            Failed to delete application \(appId):
                            - Status: \(response.status)
                            - Code: \(error.code ?? "unknown")
                            - Message: \(error.message ?? "no message")
                            - Inner Error: \(error.innerError?.message ?? "none")
                            - Request ID: \(error.innerError?.requestId ?? "none")
                            """, category: .data)
                    } else {
                        // Try to provide context based on status code alone
                        switch response.status {
                        case 400:
                            errorMessage = "Bad request - application may have dependencies"
                        case 403:
                            errorMessage = "Insufficient permissions"
                        case 404:
                            errorMessage = "Application not found"
                        case 409:
                            errorMessage = "Conflict - application may be in use"
                        case 423:
                            errorMessage = "Application is locked and cannot be deleted"
                        default:
                            Logger.shared.error("Failed to delete application \(appId): Status \(response.status) with no error body", category: .data)
                        }
                    }

                    allFailed.append((id: appId, error: errorMessage))
                }
            }
        }

        // Remove successful deletions from local cache
        // Create a new array to avoid modifying detached models
        let remainingApps = applications.filter { app in
            !allSuccessful.contains(app.id)
        }
        applications = remainingApps

        // Replace in data store with the filtered list
        dataStore.replaceApplications(with: remainingApps)

        // Post notification for UI updates
        if !allSuccessful.isEmpty {
            NotificationCenter.default.post(name: .applicationsDeleted, object: allSuccessful)
        }

        Logger.shared.info("Batch deletion complete: \(allSuccessful.count) successful, \(allFailed.count) failed")

        return (allSuccessful, allFailed)
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

    // Fetches and calculates install summary from device and user statuses
    func fetchInstallSummary(appId: String) async throws -> Application.InstallSummary {
        var summary = Application.InstallSummary()

        // Only try to fetch install summary for specific app types that support it
        // Many app types (web links, built-in apps, etc.) don't have install status endpoints
        // and will return 400 errors if we try to access them

        // Try to fetch install summary directly first (newer API, beta only)
        let summaryEndpoint = "/deviceAppManagement/mobileApps/\(appId)/installSummary"
        do {
            struct DirectSummary: Decodable {
                let installedDeviceCount: Int?
                let failedDeviceCount: Int?
                let notApplicableDeviceCount: Int?
                let notInstalledDeviceCount: Int?
                let pendingInstallDeviceCount: Int?
                let installedUserCount: Int?
                let failedUserCount: Int?
                let notApplicableUserCount: Int?
                let notInstalledUserCount: Int?
                let pendingInstallUserCount: Int?
            }

            let directSummary: DirectSummary = try await apiClient.getModel(summaryEndpoint)

            // Use direct summary if available
            summary.installedDeviceCount = directSummary.installedDeviceCount ?? 0
            summary.failedDeviceCount = directSummary.failedDeviceCount ?? 0
            summary.notApplicableDeviceCount = directSummary.notApplicableDeviceCount ?? 0
            summary.notInstalledDeviceCount = directSummary.notInstalledDeviceCount ?? 0
            summary.pendingInstallDeviceCount = directSummary.pendingInstallDeviceCount ?? 0
            summary.installedUserCount = directSummary.installedUserCount ?? 0
            summary.failedUserCount = directSummary.failedUserCount ?? 0
            summary.notApplicableUserCount = directSummary.notApplicableUserCount ?? 0
            summary.notInstalledUserCount = directSummary.notInstalledUserCount ?? 0
            summary.pendingInstallUserCount = directSummary.pendingInstallUserCount ?? 0

            Logger.shared.debug("Successfully fetched install summary for app \(appId)", category: .network)
            return summary
        } catch {
            if let graphError = error as? GraphAPIError {
                switch graphError {
                case .httpError(let statusCode):
                    if statusCode == 404 || statusCode == 400 {
                        // This is expected for many app types - not an error
                        Logger.shared.debug("Install summary not available for app \(appId) - this is normal for many app types", category: .network)
                    } else {
                        Logger.shared.debug("HTTP error \(statusCode) fetching install summary for app \(appId)", category: .network)
                    }
                case .notFound:
                    Logger.shared.debug("Install summary endpoint not found for app \(appId) - this is normal for many app types", category: .network)
                default:
                    Logger.shared.debug("Failed to fetch install summary for app \(appId): \(error)", category: .network)
                }
            } else {
                // Log unexpected errors
                Logger.shared.debug("Failed to fetch install summary for app \(appId): \(error)", category: .network)
            }
            // Return empty summary for apps without install status support
            return summary
        }
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
