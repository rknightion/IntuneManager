import Foundation
import Combine

@MainActor
final class AssignmentService: ObservableObject {
    static let shared = AssignmentService()

    @Published var activeAssignments: [Assignment] = []
    @Published var assignmentHistory: [Assignment] = []
    @Published var isProcessing = false
    @Published var currentProgress: AssignmentProgress?
    @Published var error: Error?

    private let apiClient = GraphAPIClient.shared
    private let appService = ApplicationService.shared
    private let groupService = GroupService.shared
    private let dataStore = LocalDataStore.shared
    private let maxConcurrentAssignments = 20 // Graph API batch limit
    private let retryLimit = 3

    struct AssignmentProgress {
        var total: Int
        var completed: Int
        var failed: Int
        var currentOperation: String
        var percentComplete: Double {
            guard total > 0 else { return 0 }
            return Double(completed + failed) / Double(total) * 100
        }
    }

    private init() {
        assignmentHistory = dataStore.fetchAssignments()
    }

    // MARK: - Bulk Assignment Operations

    func performBulkAssignment(_ operation: BulkAssignmentOperation) async throws -> [Assignment] {
        isProcessing = true
        defer { isProcessing = false }

        let assignments = operation.createAssignments()
        activeAssignments = assignments

        currentProgress = AssignmentProgress(
            total: assignments.count,
            completed: 0,
            failed: 0,
            currentOperation: "Validating assignments..."
        )

        Logger.shared.info("Starting bulk assignment: \(assignments.count) operations")

        // Validate assignments first (check for existing assignments)
        Logger.shared.info("Validating assignments for duplicates...")
        let validatedAssignments = await validateAssignments(assignments)

        // Track already-existing assignments as completed
        let skippedCount = assignments.count - validatedAssignments.count
        if skippedCount > 0 {
            Logger.shared.info("Skipped \(skippedCount) existing assignments")
            currentProgress?.completed = skippedCount
            currentProgress?.currentOperation = "Processing new assignments..."
        }

        // Process only new assignments in batches
        let batches = validatedAssignments.chunked(into: maxConcurrentAssignments)
        var completedAssignments: [Assignment] = []
        var failedAssignments: [Assignment] = []

        // Include the skipped (already existing) assignments as completed
        let skippedAssignments = assignments.filter { assignment in
            assignment.status == .completed && assignment.errorMessage?.contains("already exists") ?? false
        }
        completedAssignments.append(contentsOf: skippedAssignments)

        for (index, batch) in batches.enumerated() {
            currentProgress?.currentOperation = "Processing batch \(index + 1) of \(batches.count)"

            do {
                let batchResults = try await processBatch(batch)
                completedAssignments.append(contentsOf: batchResults.successful)
                failedAssignments.append(contentsOf: batchResults.failed)

                currentProgress?.completed = completedAssignments.count
                currentProgress?.failed = failedAssignments.count
            } catch {
                Logger.shared.error("Batch \(index + 1) failed: \(error)")
                // Mark all assignments in this batch as failed
                for assignment in batch {
                    assignment.status = .failed
                    assignment.errorMessage = error.localizedDescription
                    failedAssignments.append(assignment)
                }
                currentProgress?.failed += batch.count
            }
        }

        // Update assignment history
        assignmentHistory.append(contentsOf: completedAssignments)
        assignmentHistory.append(contentsOf: failedAssignments)
        persistAssignmentHistory()

        currentProgress = nil
        activeAssignments = []

        Logger.shared.info("Bulk assignment completed: \(completedAssignments.count) successful, \(failedAssignments.count) failed")

        if !failedAssignments.isEmpty {
            throw AssignmentError.partialFailure(successful: completedAssignments.count, failed: failedAssignments.count)
        }

        return completedAssignments
    }

    // MARK: - Batch Processing

    private func processBatch(_ assignments: [Assignment]) async throws -> (successful: [Assignment], failed: [Assignment]) {
        var successful: [Assignment] = []
        var failed: [Assignment] = []
        var rateLimitedAssignments: [Assignment] = []
        var maxRetryAfter: TimeInterval = 0

        // Log rate limit status before batch
        await apiClient.logRateLimitStatus()

        // Create batch requests for Graph API
        let requests = assignments.map { assignment in
            createBatchRequest(for: assignment)
        }

        // Execute batch request - the API client now handles rate limiting internally
        let responses: [BatchResponse<AppAssignment>] = try await apiClient.batchModels(requests)

        // Log rate limit status after batch
        await apiClient.logRateLimitStatus()

        // Process responses
        for (index, response) in responses.enumerated() {
            let assignment = assignments[index]

            if response.status >= 200 && response.status < 300 {
                assignment.status = .completed
                assignment.completedDate = Date()
                successful.append(assignment)
                Logger.shared.info("Assignment successful: \(assignment.applicationName) -> \(assignment.groupName)")
            } else {
                // Parse error details from response body if available
                let errorDetail = parseErrorFromResponse(response)
                assignment.errorMessage = errorDetail.message

                // Handle specific HTTP status codes
                switch response.status {
                case 409:
                    // Conflict - assignment already exists
                    assignment.status = .completed
                    assignment.errorMessage = "Assignment already exists (skipped)"
                    successful.append(assignment)
                    Logger.shared.info("Assignment already exists: \(assignment.applicationName) -> \(assignment.groupName)")

                case 429:
                    // Rate limited - add to retry list
                    assignment.status = .pending
                    rateLimitedAssignments.append(assignment)
                    if let retryAfter = parseRetryAfter(from: response) {
                        maxRetryAfter = max(maxRetryAfter, retryAfter)
                    }
                    Logger.shared.warning("Rate limited: \(assignment.applicationName) -> \(assignment.groupName)")

                case 400:
                    // Bad request - don't retry
                    assignment.status = .failed
                    assignment.errorMessage = "Invalid request: \(errorDetail.message)"
                    failed.append(assignment)
                    Logger.shared.error("Bad request for: \(assignment.applicationName) -> \(assignment.groupName): \(errorDetail.message)")

                case 403:
                    // Forbidden - insufficient permissions
                    assignment.status = .failed
                    assignment.errorMessage = "Insufficient permissions: \(errorDetail.message)"
                    failed.append(assignment)
                    Logger.shared.error("Permission denied for: \(assignment.applicationName) -> \(assignment.groupName)")

                case 404:
                    // Not found - app or group doesn't exist
                    assignment.status = .failed
                    assignment.errorMessage = "App or group not found: \(errorDetail.message)"
                    failed.append(assignment)
                    Logger.shared.error("Resource not found for: \(assignment.applicationName) -> \(assignment.groupName)")

                default:
                    // Other errors - retry if under limit
                    if assignment.retryCount < retryLimit {
                        assignment.retryCount += 1
                        assignment.status = .retrying
                        Logger.shared.warning("Retrying assignment: \(assignment.applicationName) -> \(assignment.groupName) (attempt \(assignment.retryCount))")

                        // Retry with exponential backoff
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(assignment.retryCount)) * 1_000_000_000))

                        do {
                            let retryResult = try await retrySingleAssignment(assignment)
                            successful.append(retryResult)
                        } catch {
                            assignment.status = .failed
                            assignment.errorMessage = error.localizedDescription
                            failed.append(assignment)
                        }
                    } else {
                        assignment.status = .failed
                        failed.append(assignment)
                        Logger.shared.error("Assignment failed after \(retryLimit) attempts: \(assignment.applicationName) -> \(assignment.groupName)")
                    }
                }
            }
        }

        // Handle rate-limited assignments
        if !rateLimitedAssignments.isEmpty && maxRetryAfter > 0 {
            Logger.shared.info("Waiting \(maxRetryAfter) seconds for rate limit to reset...")
            currentProgress?.currentOperation = "Rate limited - waiting \(Int(maxRetryAfter)) seconds..."
            try await Task.sleep(nanoseconds: UInt64(maxRetryAfter * 1_000_000_000))

            // Retry rate-limited assignments
            let retryResults = try await processBatch(rateLimitedAssignments)
            successful.append(contentsOf: retryResults.successful)
            failed.append(contentsOf: retryResults.failed)
        }

        return (successful, failed)
    }

    private func createBatchRequest(for assignment: Assignment) -> BatchRequest {
        let targetType = assignment.targetType

        // Create AppAssignment object with proper structure
        let appAssignment = AppAssignment(
            id: UUID().uuidString,
            intent: AppAssignment.AssignmentIntent(rawValue: assignment.intent.rawValue) ?? .required,
            target: AppAssignment.AssignmentTarget(
                type: targetType,
                groupId: targetType.requiresGroupId ? assignment.groupId : nil,
                groupName: nil,  // Don't include groupName in the request
                deviceAndAppManagementAssignmentFilterId: assignment.filter?.filterId,
                deviceAndAppManagementAssignmentFilterType: assignment.filter?.filterType?.rawValue
            ),
            settings: nil,
            source: "IntuneManager",
            sourceId: assignment.batchId
        )

        return BatchRequest(
            method: "POST",
            url: "/deviceAppManagement/mobileApps/\(assignment.applicationId)/assignments",
            body: appAssignment,
            headers: ["Content-Type": "application/json"]
        )
    }

    private func retrySingleAssignment(_ assignment: Assignment) async throws -> Assignment {
        let updatedAssignment = assignment

        let targetType = assignment.targetType
        let appAssignment = AppAssignment(
            id: assignment.id,
            intent: AppAssignment.AssignmentIntent(rawValue: assignment.intent.rawValue) ?? .required,
            target: AppAssignment.AssignmentTarget(
                type: targetType,
                groupId: targetType.requiresGroupId ? assignment.groupId : nil,
                groupName: targetType.requiresGroupId ? assignment.groupName : nil,
                deviceAndAppManagementAssignmentFilterId: nil,
                deviceAndAppManagementAssignmentFilterType: nil
            ),
            settings: nil,
            source: "IntuneManager",
            sourceId: assignment.batchId
        )

        _ = try await appService.createAssignment(
            appId: assignment.applicationId,
            assignment: appAssignment
        )

        updatedAssignment.status = .completed
        updatedAssignment.completedDate = Date()

        return updatedAssignment
    }

    // MARK: - Assignment Management

    func cancelActiveAssignments() {
        for index in activeAssignments.indices {
            if activeAssignments[index].status == .pending || activeAssignments[index].status == .inProgress {
                activeAssignments[index].status = .cancelled
            }
        }

        isProcessing = false
        currentProgress = nil

        Logger.shared.info("Cancelled active assignments")
    }

    func retryFailedAssignments() async throws -> [Assignment] {
        let failedAssignments = assignmentHistory.filter { $0.status == .failed }

        guard !failedAssignments.isEmpty else {
            throw AssignmentError.noFailedAssignments
        }

        let retryOperation = BulkAssignmentOperation(
            applications: [], // Will be resolved from assignment IDs
            groups: [],       // Will be resolved from assignment IDs
            intent: failedAssignments.first?.intent ?? .required
        )

        // Reset failed assignments for retry
        let resetAssignments = failedAssignments.map { assignment -> Assignment in
            assignment.status = .pending
            assignment.retryCount = 0
            assignment.errorMessage = nil
            return assignment
        }

        activeAssignments = resetAssignments

        return try await performBulkAssignment(retryOperation)
    }

    // MARK: - History Management

    func clearAssignmentHistory() {
        assignmentHistory.removeAll()
        saveAssignmentHistory()
    }

    private func saveAssignmentHistory() {
        // Save assignment history to persistent storage if needed
        // For now, just keeping in memory
    }

    func getAssignmentStatistics() -> AssignmentStatistics {
        let total = assignmentHistory.count
        let completed = assignmentHistory.filter { $0.status == .completed }.count
        let failed = assignmentHistory.filter { $0.status == .failed }.count
        let pending = assignmentHistory.filter { $0.status == .pending }.count

        return AssignmentStatistics(
            total: total,
            completed: completed,
            failed: failed,
            pending: pending
        )
    }

    // Fetch actual assignment statistics from Intune API
    func fetchIntuneAssignmentStatistics() async throws -> IntuneAssignmentStats {
        Logger.shared.info("Fetching assignment statistics from Intune API", category: .network)

        // Get all mobile apps to count their assignments
        let applications = try await appService.fetchApplications(forceRefresh: false)

        var totalAssignments = 0
        var appAssignmentCounts: [String: Int] = [:]
        var appsByIntent: [Assignment.AssignmentIntent: [AppIntentDetail]] = [:]

        // Count assignments across all apps
        for app in applications {
            if let assignments = app.assignments {
                totalAssignments += assignments.count
                appAssignmentCounts[app.id] = assignments.count
            }
        }

        // Group assignments by intent type and collect app details
        var intentCounts: [Assignment.AssignmentIntent: Int] = [:]
        for app in applications {
            if let assignments = app.assignments {
                // Group assignments by intent for this app
                var intentGroups: [Assignment.AssignmentIntent: [String]] = [:]

                for assignment in assignments {
                    let intent = Assignment.AssignmentIntent(rawValue: assignment.intent.rawValue) ?? .available
                    intentCounts[intent, default: 0] += 1

                    // Collect group names for this intent
                    let groupName = assignment.target.groupName ?? "All Users/Devices"
                    intentGroups[intent, default: []].append(groupName)
                }

                // Create AppIntentDetail for each intent this app has
                for (intent, groups) in intentGroups {
                    let appDetail = AppIntentDetail(
                        id: app.id,
                        appName: app.displayName,
                        appType: app.appType,
                        groupNames: Array(Set(groups)).sorted() // Remove duplicates and sort
                    )
                    appsByIntent[intent, default: []].append(appDetail)
                }
            }
        }

        // Sort apps by name within each intent
        for intent in appsByIntent.keys {
            appsByIntent[intent]?.sort { $0.appName < $1.appName }
        }

        return IntuneAssignmentStats(
            totalAssignments: totalAssignments,
            assignmentsByIntent: intentCounts,
            totalAppsWithAssignments: appAssignmentCounts.values.filter { $0 > 0 }.count,
            totalApps: applications.count,
            appsByIntent: appsByIntent
        )
    }

    // MARK: - Private Methods

    private func persistAssignmentHistory() {
        let recentHistory = Array(assignmentHistory.suffix(1000))
        dataStore.storeAssignments(recentHistory)
    }
}

// MARK: - Supporting Types

struct AssignmentStatistics {
    let total: Int
    let completed: Int
    let failed: Int
    let pending: Int
}

struct IntuneAssignmentStats {
    let totalAssignments: Int
    let assignmentsByIntent: [Assignment.AssignmentIntent: Int]
    let totalAppsWithAssignments: Int
    let totalApps: Int
    let appsByIntent: [Assignment.AssignmentIntent: [AppIntentDetail]]
}

struct AppIntentDetail: Identifiable {
    let id: String
    let appName: String
    let appType: Application.AppType
    let groupNames: [String]
}

enum AssignmentError: LocalizedError {
    case partialFailure(successful: Int, failed: Int)
    case noFailedAssignments
    case invalidConfiguration

    var errorDescription: String? {
        switch self {
        case .partialFailure(let successful, let failed):
            return "Partial failure: \(successful) successful, \(failed) failed"
        case .noFailedAssignments:
            return "No failed assignments to retry"
        case .invalidConfiguration:
            return "Invalid assignment configuration"
        }
    }
}

    // MARK: - Error Parsing Helpers

    private func parseErrorFromResponse(_ response: BatchResponse<AppAssignment>) -> (message: String, code: String?) {
        // Try to parse error from response body if it exists
        // The body might contain detailed error information
        if response.status == 409 {
            return ("Assignment already exists for this app and group", "Conflict")
        } else if response.status == 429 {
            return ("Too many requests. Please wait and try again.", "TooManyRequests")
        } else if response.status == 400 {
            return ("Invalid assignment configuration", "BadRequest")
        } else if response.status == 403 {
            return ("You don't have permission to create this assignment", "Forbidden")
        } else if response.status == 404 {
            return ("The app or group specified doesn't exist", "NotFound")
        }

        return ("Assignment failed with status \(response.status)", nil)
    }

    private func parseRetryAfter(from response: BatchResponse<AppAssignment>) -> TimeInterval? {
        // Check for Retry-After header in response
        if let retryAfterString = response.headers?["Retry-After"],
           let retryAfter = Double(retryAfterString) {
            return retryAfter
        }
        // Default retry after 10 seconds if not specified
        return 10
    }

    // MARK: - Pre-flight Validation

    func validateAssignments(_ assignments: [Assignment]) async -> [Assignment] {
        var validatedAssignments: [Assignment] = []

        for assignment in assignments {
            // Check if assignment already exists
            do {
                let existingAssignments = try await ApplicationService.shared.getApplicationAssignments(appId: assignment.applicationId)

                let alreadyExists = existingAssignments.contains { existing in
                    // Check if there's already an assignment to the same group with same intent
                    if let existingGroupId = existing.target.groupId {
                        return existingGroupId == assignment.groupId &&
                               existing.intent.rawValue == assignment.intent.rawValue
                    }
                    return false
                }

                if alreadyExists {
                    assignment.status = .completed
                    assignment.errorMessage = "Assignment already exists (skipped)"
                    assignment.completedDate = Date()
                    Logger.shared.info("Skipping existing assignment: \(assignment.applicationName) -> \(assignment.groupName)")
                } else {
                    validatedAssignments.append(assignment)
                }
            } catch {
                // If we can't check, include it for assignment attempt
                validatedAssignments.append(assignment)
                Logger.shared.warning("Could not validate assignment: \(assignment.applicationName) -> \(assignment.groupName)")
            }
        }

        return validatedAssignments
    }

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
