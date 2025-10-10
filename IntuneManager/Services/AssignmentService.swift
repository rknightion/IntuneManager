import Foundation
import Combine
import SwiftUI

// Flexible assignment request struct for Graph API
struct FlexibleAppAssignment: Encodable {
    let odataType: String = "#microsoft.graph.mobileAppAssignment"
    let id: String
    let intent: String
    let target: Target
    let settings: Encodable?
    let source: String?
    let sourceId: String?

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case id
        case intent
        case target
        case settings
        case source
        case sourceId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(odataType, forKey: .odataType)
        try container.encode(id, forKey: .id)
        try container.encode(intent, forKey: .intent)
        try container.encode(target, forKey: .target)
        if let settings = settings {
            try settings.encode(to: container.superEncoder(forKey: .settings))
        }
        // Don't encode source and sourceId at all if they're nil
        // Graph API doesn't expect these fields for the /assign endpoint
    }

    struct Target: Encodable {
        let odataType: String
        let groupId: String?
        let deviceAndAppManagementAssignmentFilterId: String?
        let deviceAndAppManagementAssignmentFilterType: String?

        enum CodingKeys: String, CodingKey {
            case odataType = "@odata.type"
            case groupId
            case deviceAndAppManagementAssignmentFilterId
            case deviceAndAppManagementAssignmentFilterType
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(odataType, forKey: .odataType)
            // Only encode non-nil values - Graph API doesn't like explicit nulls
            if let groupId = groupId {
                try container.encode(groupId, forKey: .groupId)
            }
            if let filterId = deviceAndAppManagementAssignmentFilterId {
                try container.encode(filterId, forKey: .deviceAndAppManagementAssignmentFilterId)
            }
            if let filterType = deviceAndAppManagementAssignmentFilterType {
                try container.encode(filterType, forKey: .deviceAndAppManagementAssignmentFilterType)
            }
        }
    }
}

@MainActor
final class AssignmentService: ObservableObject {
    static let shared = AssignmentService()

    @Published var activeAssignments: [Assignment] = []
    @Published var assignmentHistory: [Assignment] = []
    @Published var isProcessing = false
    @Published var currentProgress: AssignmentProgress?
    @Published var error: Error?
    @Published var assignmentLogs: [AssignmentLogEntry] = []
    @Published var perAppProgress: [String: AppProgress] = [:]

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
        var isVerifying: Bool = false  // Track if we're in verification phase
        var percentComplete: Double {
            guard total > 0 else { return 0 }
            return Double(completed + failed) / Double(total) * 100
        }
    }

    struct AppProgress: Identifiable {
        let id: String  // appId
        let appName: String
        var status: AppStatus
        var groupsTotal: Int
        var groupsCompleted: Int
        var groupsFailed: Int

        enum AppStatus {
            case pending
            case processing
            case completed
            case failed
        }

        var percentComplete: Double {
            guard groupsTotal > 0 else { return 0 }
            return Double(groupsCompleted + groupsFailed) / Double(groupsTotal) * 100
        }

        var isComplete: Bool {
            groupsCompleted + groupsFailed >= groupsTotal
        }
    }

    struct AssignmentLogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let level: LogLevel
        let appName: String?
        let groupName: String?
        let message: String

        enum LogLevel: String {
            case info = "Info"
            case success = "Success"
            case warning = "Warning"
            case error = "Error"

            var color: Color {
                switch self {
                case .info: return .blue
                case .success: return .green
                case .warning: return .orange
                case .error: return .red
                }
            }

            var icon: String {
                switch self {
                case .info: return "info.circle.fill"
                case .success: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.circle.fill"
                }
            }
        }
    }

    private init() {
        assignmentHistory = dataStore.fetchAssignments()
    }

    // MARK: - Per-App Progress Tracking

    private func updateAppProgress(appId: String, success: Bool) {
        guard var progress = perAppProgress[appId] else { return }

        if success {
            progress.groupsCompleted += 1
        } else {
            progress.groupsFailed += 1
        }

        // Update status based on progress
        if progress.isComplete {
            if progress.groupsFailed == 0 {
                progress.status = .completed
            } else if progress.groupsCompleted == 0 {
                progress.status = .failed
            } else {
                progress.status = .completed  // Partial success still counts as completed
            }
        } else if progress.groupsCompleted > 0 || progress.groupsFailed > 0 {
            progress.status = .processing
        }

        perAppProgress[appId] = progress
    }

    // MARK: - Logging

    private func log(_ level: AssignmentLogEntry.LogLevel, _ message: String, appName: String? = nil, groupName: String? = nil) {
        let entry = AssignmentLogEntry(
            timestamp: Date(),
            level: level,
            appName: appName,
            groupName: groupName,
            message: message
        )
        assignmentLogs.append(entry)

        // Keep logs limited to last 500 entries to avoid memory issues
        if assignmentLogs.count > 500 {
            assignmentLogs.removeFirst(assignmentLogs.count - 500)
        }
    }

    func clearLogs() {
        assignmentLogs.removeAll()
    }

    // MARK: - Bulk Assignment Operations

    func performBulkAssignment(_ operation: BulkAssignmentOperation) async throws -> [Assignment] {
        isProcessing = true
        defer { isProcessing = false }

        let assignments = operation.createAssignments()
        activeAssignments = assignments

        // Clear old logs and start fresh
        clearLogs()
        log(.info, "Starting bulk assignment operation")
        log(.info, "Total assignments to process: \(assignments.count)")

        // Initialize per-app progress tracking
        perAppProgress.removeAll()
        let assignmentsByApp = Dictionary(grouping: assignments) { $0.applicationId }
        for (appId, appAssignments) in assignmentsByApp {
            let appName = appAssignments.first?.applicationName ?? "Unknown App"
            perAppProgress[appId] = AppProgress(
                id: appId,
                appName: appName,
                status: .pending,
                groupsTotal: appAssignments.count,
                groupsCompleted: 0,
                groupsFailed: 0
            )
        }

        // Check if we already have cached assignment data for all apps
        let allAppsHaveCachedAssignments = operation.applications.allSatisfy { app in
            app.assignments != nil
        }

        currentProgress = AssignmentProgress(
            total: assignments.count,
            completed: 0,
            failed: 0,
            currentOperation: allAppsHaveCachedAssignments ? "Processing assignments..." : "Validating assignments..."
        )

        Logger.shared.info("Starting bulk assignment: \(assignments.count) operations")

        let validatedAssignments: [Assignment]

        if allAppsHaveCachedAssignments {
            // We already have assignment data, validate using cached data
            Logger.shared.info("Using cached assignment data for validation")
            validatedAssignments = validateAssignmentsFromCache(assignments, operation.applications)

            // Track already-existing assignments as completed
            let skippedCount = assignments.count - validatedAssignments.count
            if skippedCount > 0 {
                Logger.shared.info("Skipped \(skippedCount) existing assignments (from cache)")
                currentProgress?.completed = skippedCount
                currentProgress?.currentOperation = "Processing new assignments..."

                // Update per-app progress for skipped assignments
                let skippedAssignments = assignments.filter { !validatedAssignments.contains($0) }
                for skipped in skippedAssignments {
                    updateAppProgress(appId: skipped.applicationId, success: true)
                }
            }
        } else {
            // Need to fetch assignment data from API
            Logger.shared.info("Fetching assignment data for validation...")
            validatedAssignments = await validateAssignments(assignments)

            // Track already-existing assignments as completed
            let skippedCount = assignments.count - validatedAssignments.count
            if skippedCount > 0 {
                Logger.shared.info("Skipped \(skippedCount) existing assignments")
                currentProgress?.completed = skippedCount
                currentProgress?.currentOperation = "Processing new assignments..."

                // Update per-app progress for skipped assignments
                let skippedAssignments = assignments.filter { !validatedAssignments.contains($0) }
                for skipped in skippedAssignments {
                    updateAppProgress(appId: skipped.applicationId, success: true)
                }
            }
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

        // Enter verification phase - keep progress active for UI
        currentProgress?.isVerifying = true
        currentProgress?.currentOperation = "Verifying assignments with Microsoft Graph..."

        Logger.shared.info("Bulk assignment completed: \(completedAssignments.count) successful, \(failedAssignments.count) failed")

        // Verify and refresh if any assignments were successful
        if !completedAssignments.isEmpty {
            Logger.shared.info("Starting verification and background refresh of applications...")

            // Small delay to allow Graph API to process the assignments
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

            currentProgress?.currentOperation = "Refreshing application data..."

            do {
                // Refresh applications and their assignments to update cache
                _ = try await appService.fetchApplications(forceRefresh: true)
                Logger.shared.info("Background refresh completed - application cache updated")
                currentProgress?.currentOperation = "Assignment verification complete"
            } catch {
                Logger.shared.error("Background refresh failed: \(error.localizedDescription)")
                currentProgress?.currentOperation = "Verification complete (refresh failed)"
            }

            // Keep the progress visible for a moment so users can see completion
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        // Now clear progress
        currentProgress = nil
        activeAssignments = []

        if !failedAssignments.isEmpty {
            throw AssignmentError.partialFailure(successful: completedAssignments.count, failed: failedAssignments.count)
        }

        return completedAssignments
    }

    // MARK: - Batch Processing

    // We use the Microsoft Graph batch API for assignments because:
    // 1. It reduces network round trips (up to 20 assignments per request vs 1)
    // 2. For hundreds of apps, this means ~5-10 batch requests instead of hundreds of individual calls
    // 3. Better performance and less overhead
    // 4. Batch requests still respect rate limits but are more efficient
    // The complexity is worth it for bulk operations like this

    private func processBatch(_ assignments: [Assignment]) async throws -> (successful: [Assignment], failed: [Assignment]) {
        var successful: [Assignment] = []
        var failed: [Assignment] = []
        var rateLimitedAssignments: [Assignment] = []
        var maxRetryAfter: TimeInterval = 0

        // Log rate limit status before batch
        await apiClient.logRateLimitStatus()

        // Create batch requests for Graph API with proper settings
        var requests: [BatchRequest] = []
        for assignment in assignments {
            let request = createBatchRequest(for: assignment)
            requests.append(request)
        }

        // Update progress before batch submission
        currentProgress?.currentOperation = "Submitting batch to Microsoft Graph..."

        // Execute batch request - the API client now handles rate limiting internally
        // The /assign endpoint returns 204 No Content, so we use EmptyResponse
        struct AssignActionResponse: Decodable, Sendable {}
        let responses: [BatchResponse<AssignActionResponse>] = try await apiClient.batchModels(requests)

        // Log rate limit status after batch
        await apiClient.logRateLimitStatus()

        // Update progress for response processing
        currentProgress?.currentOperation = "Processing batch responses..."

        // Process responses
        for (index, response) in responses.enumerated() {
            let assignment = assignments[index]

            if response.status >= 200 && response.status < 300 {
                // Success - includes 204 No Content which is expected for /assign endpoint
                assignment.status = .completed
                assignment.completedDate = Date()
                successful.append(assignment)
                updateAppProgress(appId: assignment.applicationId, success: true)
                Logger.shared.info("Assignment successful: \(assignment.applicationName) -> \(assignment.groupName)")
                log(.success, "Assignment completed successfully", appName: assignment.applicationName, groupName: assignment.groupName)
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
                    updateAppProgress(appId: assignment.applicationId, success: true)
                    Logger.shared.info("Assignment already exists: \(assignment.applicationName) -> \(assignment.groupName)")

                case 429:
                    // Rate limited - add to retry list
                    assignment.status = .pending
                    assignment.errorCategory = "rateLimit"
                    rateLimitedAssignments.append(assignment)
                    if let retryAfter = parseRetryAfter(from: response) {
                        maxRetryAfter = max(maxRetryAfter, retryAfter)
                    }
                    Logger.shared.warning("Rate limited: \(assignment.applicationName) -> \(assignment.groupName)")

                case 400:
                    // Bad request - don't retry
                    assignment.status = .failed
                    assignment.errorMessage = "Invalid request: \(errorDetail.message)"
                    assignment.errorCategory = "validation"
                    assignment.failureTimestamp = Date()
                    failed.append(assignment)
                    updateAppProgress(appId: assignment.applicationId, success: false)
                    Logger.shared.error("Bad request for: \(assignment.applicationName) -> \(assignment.groupName): \(errorDetail.message)")
                    log(.error, "Invalid request: \(errorDetail.message)", appName: assignment.applicationName, groupName: assignment.groupName)

                case 403:
                    // Forbidden - insufficient permissions
                    assignment.status = .failed
                    assignment.errorMessage = "Insufficient permissions: \(errorDetail.message)"
                    assignment.errorCategory = "permission"
                    assignment.failureTimestamp = Date()
                    failed.append(assignment)
                    updateAppProgress(appId: assignment.applicationId, success: false)
                    Logger.shared.error("Permission denied for: \(assignment.applicationName) -> \(assignment.groupName)")
                    log(.error, "Insufficient permissions", appName: assignment.applicationName, groupName: assignment.groupName)

                case 404:
                    // Not found - app or group doesn't exist
                    assignment.status = .failed
                    assignment.errorMessage = "App or group not found: \(errorDetail.message)"
                    assignment.errorCategory = "validation"
                    assignment.failureTimestamp = Date()
                    failed.append(assignment)
                    updateAppProgress(appId: assignment.applicationId, success: false)
                    Logger.shared.error("Resource not found for: \(assignment.applicationName) -> \(assignment.groupName)")
                    log(.error, "App or group not found", appName: assignment.applicationName, groupName: assignment.groupName)

                default:
                    // Other errors - retry if under limit
                    assignment.errorCategory = response.status >= 500 ? "network" : "unknown"
                    if assignment.retryCount < retryLimit {
                        assignment.retryCount += 1
                        assignment.status = .retrying
                        Logger.shared.warning("Retrying assignment: \(assignment.applicationName) -> \(assignment.groupName) (attempt \(assignment.retryCount))")

                        // Retry with exponential backoff
                        try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(assignment.retryCount)) * 1_000_000_000))

                        do {
                            let retryResult = try await retrySingleAssignment(assignment)
                            successful.append(retryResult)
                            updateAppProgress(appId: assignment.applicationId, success: true)
                        } catch {
                            assignment.status = .failed
                            assignment.errorMessage = error.localizedDescription
                            assignment.errorCategory = "network"
                            assignment.failureTimestamp = Date()
                            failed.append(assignment)
                            updateAppProgress(appId: assignment.applicationId, success: false)
                        }
                    } else {
                        assignment.status = .failed
                        assignment.failureTimestamp = Date()
                        failed.append(assignment)
                        updateAppProgress(appId: assignment.applicationId, success: false)
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

        // Prepare the settings based on intent
        var settingsValue: Encodable?

        // For uninstall intent, don't include ANY settings - let Intune use defaults
        if assignment.intent == .uninstall {
            settingsValue = nil
        } else {
            // For non-uninstall intents, use full settings
            if let graphSettings = assignment.graphSettings {
                if let iosVppSettings = graphSettings.iosVppSettings {
                    settingsValue = iosVppSettings
                } else if let iosLobSettings = graphSettings.iosLobSettings {
                    settingsValue = iosLobSettings
                } else if let macosVppSettings = graphSettings.macosVppSettings {
                    settingsValue = macosVppSettings
                } else if let macosLobSettings = graphSettings.macosLobSettings {
                    settingsValue = macosLobSettings
                } else if let windowsSettings = graphSettings.windowsSettings {
                    settingsValue = windowsSettings
                }
            }
        }

        // Create flexible assignment with proper settings
        let flexibleAssignment = FlexibleAppAssignment(
            id: UUID().uuidString,
            intent: assignment.intent.rawValue,
            target: FlexibleAppAssignment.Target(
                odataType: targetType.rawValue,  // targetType.rawValue already includes the full type string
                groupId: targetType.requiresGroupId ? assignment.groupId : nil,
                deviceAndAppManagementAssignmentFilterId: nil,  // Set to nil for now
                deviceAndAppManagementAssignmentFilterType: nil  // Set to nil for now
            ),
            settings: settingsValue,
            source: nil,  // Remove source field - might not be valid for /assign endpoint
            sourceId: nil  // Remove sourceId field - might not be valid for /assign endpoint
        )

        // Wrap the assignment in the required format for the /assign action endpoint
        struct AssignRequest: Encodable {
            let mobileAppAssignments: [FlexibleAppAssignment]
        }

        let requestBody = AssignRequest(mobileAppAssignments: [flexibleAssignment])

        // Debug logging - capture and log the JSON being sent
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let jsonData = try encoder.encode(requestBody)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                Logger.shared.debug("Assignment JSON for \(assignment.applicationName) -> \(assignment.groupName):")
                Logger.shared.debug("\(jsonString)")
            }
        } catch {
            Logger.shared.error("Failed to encode assignment JSON for debugging: \(error)")
        }

        return BatchRequest(
            method: "POST",
            url: "/deviceAppManagement/mobileApps/\(assignment.applicationId)/assign",
            body: requestBody,
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

    /// Retry failed assignments with context-aware exponential backoff
    /// - Parameters:
    ///   - selective: If true, only retry transient errors (network, rateLimit). If false, retry all failed.
    ///   - maxAttempts: Maximum retry attempts per assignment (default 5)
    /// - Returns: Array of successfully retried assignments
    func retryFailedAssignments(selective: Bool = true, maxAttempts: Int = 5) async throws -> [Assignment] {
        let failedAssignments = assignmentHistory.filter { $0.status == .failed }

        guard !failedAssignments.isEmpty else {
            throw AssignmentError.noFailedAssignments
        }

        // Filter based on selective mode
        let assignmentsToRetry: [Assignment]
        if selective {
            // Only retry transient errors (network, rateLimit, unknown)
            assignmentsToRetry = failedAssignments.filter { assignment in
                guard let category = assignment.errorCategory else { return true }
                return category == "network" || category == "rateLimit" || category == "unknown"
            }

            if assignmentsToRetry.isEmpty {
                log(.warning, "No retryable assignments found (only permission/validation errors)")
                throw AssignmentError.invalidConfiguration(reason: "All failed assignments have non-retryable errors (permission/validation)")
            }
        } else {
            assignmentsToRetry = failedAssignments
        }

        log(.info, "Starting retry of \(assignmentsToRetry.count) failed assignments (selective: \(selective))")

        // Filter out assignments that have exceeded max attempts
        let eligibleAssignments = assignmentsToRetry.filter { $0.retryCount < maxAttempts }

        if eligibleAssignments.isEmpty {
            log(.warning, "All failed assignments have exceeded max retry attempts (\(maxAttempts))")
            throw AssignmentError.invalidConfiguration(reason: "All assignments have exceeded maximum retry attempts")
        }

        // Calculate exponential backoff delays for each assignment
        var successful: [Assignment] = []
        var failed: [Assignment] = []

        isProcessing = true
        defer { isProcessing = false }

        currentProgress = AssignmentProgress(
            total: eligibleAssignments.count,
            completed: 0,
            failed: 0,
            currentOperation: "Retrying failed assignments..."
        )

        // Process retries with exponential backoff
        for assignment in eligibleAssignments {
            // Calculate backoff delay: min(2^retryCount, 60) seconds
            let backoffSeconds = min(pow(2.0, Double(assignment.retryCount)), 60.0)

            // Check if we need to wait based on failure timestamp
            if let failureTime = assignment.failureTimestamp {
                let timeSinceFailure = Date().timeIntervalSince(failureTime)
                let remainingWait = backoffSeconds - timeSinceFailure

                if remainingWait > 0 {
                    log(.info, "Waiting \(Int(remainingWait))s before retrying", appName: assignment.applicationName, groupName: assignment.groupName)
                    currentProgress?.currentOperation = "Waiting \(Int(remainingWait))s before retry..."
                    try await Task.sleep(nanoseconds: UInt64(remainingWait * 1_000_000_000))
                }
            }

            // Increment retry count
            assignment.retryCount += 1
            assignment.status = .retrying

            currentProgress?.currentOperation = "Retrying: \(assignment.applicationName) → \(assignment.groupName) (attempt \(assignment.retryCount))"
            log(.info, "Retry attempt \(assignment.retryCount)/\(maxAttempts)", appName: assignment.applicationName, groupName: assignment.groupName)

            do {
                // Create single-assignment batch
                let batch = [assignment]
                let result = try await processBatch(batch)

                if !result.successful.isEmpty {
                    successful.append(contentsOf: result.successful)
                    currentProgress?.completed += 1
                    log(.success, "Retry successful on attempt \(assignment.retryCount)", appName: assignment.applicationName, groupName: assignment.groupName)
                } else {
                    failed.append(contentsOf: result.failed)
                    currentProgress?.failed += 1
                    log(.error, "Retry failed on attempt \(assignment.retryCount)", appName: assignment.applicationName, groupName: assignment.groupName)
                }
            } catch {
                assignment.status = .failed
                assignment.errorMessage = error.localizedDescription
                assignment.failureTimestamp = Date()
                failed.append(assignment)
                currentProgress?.failed += 1
                log(.error, "Retry attempt failed: \(error.localizedDescription)", appName: assignment.applicationName, groupName: assignment.groupName)
            }
        }

        // Update history
        assignmentHistory.append(contentsOf: successful)
        assignmentHistory.append(contentsOf: failed)
        persistAssignmentHistory()

        currentProgress = nil

        let successCount = successful.count
        let failCount = failed.count
        log(.info, "Retry operation completed: \(successCount) successful, \(failCount) failed")

        if !failed.isEmpty {
            throw AssignmentError.partialFailure(successful: successCount, failed: failCount, context: "Some retries failed")
        }

        return successful
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
    case partialFailure(successful: Int, failed: Int, context: String? = nil)
    case noFailedAssignments
    case invalidConfiguration(reason: String? = nil)
    case allAssignmentsFailed(count: Int, reason: String? = nil)
    case permissionDenied(missingPermissions: [String]? = nil)
    case conflictDetected(conflicts: Int, description: String? = nil)

    var errorDescription: String? {
        switch self {
        case .partialFailure(let successful, let failed, let context):
            if let context = context {
                return "Partial failure: \(successful) successful, \(failed) failed - \(context)"
            }
            return "Partial failure: \(successful) successful, \(failed) failed"

        case .noFailedAssignments:
            return "No failed assignments to retry"

        case .invalidConfiguration(let reason):
            if let reason = reason {
                return "Invalid assignment configuration: \(reason)"
            }
            return "Invalid assignment configuration"

        case .allAssignmentsFailed(let count, let reason):
            if let reason = reason {
                return "All \(count) assignments failed: \(reason)"
            }
            return "All \(count) assignments failed"

        case .permissionDenied(let permissions):
            if let permissions = permissions {
                return "Permission denied. Missing required permissions:\n\(permissions.map { "• \($0)" }.joined(separator: "\n"))"
            }
            return "Permission denied. You don't have the required permissions for this operation."

        case .conflictDetected(let conflicts, let description):
            if let description = description {
                return "\(conflicts) conflict\(conflicts == 1 ? "" : "s") detected: \(description)"
            }
            return "\(conflicts) assignment conflict\(conflicts == 1 ? "" : "s") detected"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .partialFailure(let successful, let failed, _):
            if failed > successful {
                return "Most assignments failed. Review the error details below and check your permissions. You can retry failed assignments after fixing the issues."
            }
            return "Most assignments succeeded. Review failed assignments below and retry them individually if needed."

        case .noFailedAssignments:
            return nil

        case .invalidConfiguration(let reason):
            if let reason = reason, reason.contains("settings") {
                return "Review the assignment settings for each app type and ensure all required fields are filled correctly."
            }
            return "Check your assignment configuration and try again. Ensure all apps, groups, and intents are valid."

        case .allAssignmentsFailed(_, let reason):
            if let reason = reason, reason.contains("permission") || reason.contains("forbidden") {
                return "Contact your administrator to grant the necessary Microsoft Graph permissions for app assignment management."
            }
            return "All assignments failed. This may indicate a permission issue or Microsoft Graph outage. Check your permissions and try again later."

        case .permissionDenied:
            return "Contact your Azure AD administrator to request the following permissions for this app:\n\n• DeviceManagementApps.ReadWrite.All\n• Group.Read.All\n\nThese permissions are required to manage Intune app assignments."

        case .conflictDetected(let conflicts, _):
            if conflicts == 1 {
                return "This assignment already exists. You can modify it using the Applications tab or delete it and create a new one."
            }
            return "These assignments already exist. Review the conflict details and decide whether to skip them or modify the existing assignments."
        }
    }

    var failureReason: String? {
        switch self {
        case .partialFailure:
            return "Some assignments could not be created"
        case .noFailedAssignments:
            return "No assignments failed"
        case .invalidConfiguration:
            return "Configuration validation failed"
        case .allAssignmentsFailed:
            return "Assignment creation failed"
        case .permissionDenied:
            return "Insufficient permissions"
        case .conflictDetected:
            return "Duplicate assignments detected"
        }
    }

    var isRetriable: Bool {
        switch self {
        case .partialFailure, .allAssignmentsFailed:
            return true
        case .permissionDenied, .invalidConfiguration, .noFailedAssignments, .conflictDetected:
            return false
        }
    }
}

    // MARK: - Error Parsing Helpers

    private func parseErrorFromResponse<T>(_ response: BatchResponse<T>) -> (message: String, code: String?) {
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

    private func parseRetryAfter<T>(from response: BatchResponse<T>) -> TimeInterval? {
        // Check for Retry-After header in response
        if let retryAfterString = response.headers?["Retry-After"],
           let retryAfter = Double(retryAfterString) {
            return retryAfter
        }
        // Default retry after 10 seconds if not specified
        return 10
    }

    // MARK: - Pre-flight Validation

    private func validateAssignmentsFromCache(_ assignments: [Assignment], _ applications: [Application]) -> [Assignment] {
        var validatedAssignments: [Assignment] = []

        // Build a map of app ID to cached assignments for quick lookup
        let appAssignmentsMap = Dictionary(uniqueKeysWithValues: applications.compactMap { app in
            app.assignments.map { (app.id, $0) }
        })

        for assignment in assignments {
            let existingAssignments = appAssignmentsMap[assignment.applicationId] ?? []

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
                Logger.shared.info("Skipping existing assignment (from cache): \(assignment.applicationName) -> \(assignment.groupName)")
            } else {
                validatedAssignments.append(assignment)
            }
        }

        Logger.shared.info("Cache validation complete: \(validatedAssignments.count) new assignments, \(assignments.count - validatedAssignments.count) skipped")
        return validatedAssignments
    }

    func validateAssignments(_ assignments: [Assignment]) async -> [Assignment] {
        var validatedAssignments: [Assignment] = []

        // Group assignments by applicationId to reduce API calls
        let assignmentsByApp = Dictionary(grouping: assignments) { $0.applicationId }
        let uniqueAppIds = Array(assignmentsByApp.keys)

        // Cache existing assignments per app to avoid duplicate calls
        var existingAssignmentsCache: [String: [AppAssignment]] = [:]

        // If we have a lot of apps, batch the GET requests
        if uniqueAppIds.count > 5 {
            // Use batch API for efficiency
            let batches = uniqueAppIds.chunked(into: 20)  // Graph API batch limit

            for batch in batches {
                let batchRequests = batch.map { appId in
                    BatchRequest(
                        id: appId,
                        method: "GET",
                        url: "/deviceAppManagement/mobileApps/\(appId)/assignments"
                    )
                }

                do {
                    // Response structure for assignments list
                    struct AssignmentsResponse: Decodable, Sendable {
                        let value: [AppAssignment]
                    }

                    let responses: [BatchResponse<AssignmentsResponse>] = try await GraphAPIClient.shared.batchModels(batchRequests)

                    for (index, response) in responses.enumerated() {
                        let appId = batch[index]
                        if response.status == 200, let body = response.body {
                            existingAssignmentsCache[appId] = body.value
                            let appName = assignmentsByApp[appId]?.first?.applicationName ?? appId
                            Logger.shared.info("Fetched \(body.value.count) existing assignments for app \(appName)")
                        } else {
                            existingAssignmentsCache[appId] = []
                            Logger.shared.warning("Could not fetch existing assignments for app \(appId)")
                        }
                    }
                } catch {
                    Logger.shared.error("Batch fetch failed, falling back to individual requests: \(error)")
                    // Fall back to individual requests if batch fails
                    for appId in batch {
                        do {
                            let existingAssignments = try await ApplicationService.shared.getApplicationAssignments(appId: appId)
                            existingAssignmentsCache[appId] = existingAssignments
                        } catch {
                            existingAssignmentsCache[appId] = []
                        }
                    }
                }
            }
        } else {
            // For a small number of apps, use individual requests
            for (appId, appAssignments) in assignmentsByApp {
                do {
                    let existingAssignments = try await ApplicationService.shared.getApplicationAssignments(appId: appId)
                    existingAssignmentsCache[appId] = existingAssignments
                    Logger.shared.info("Fetched \(existingAssignments.count) existing assignments for app \(appAssignments.first?.applicationName ?? appId)")
                } catch {
                    Logger.shared.warning("Could not fetch existing assignments for app \(appId): \(error)")
                    existingAssignmentsCache[appId] = []
                }
            }
        }

        // Now validate each assignment using the cached data
        for assignment in assignments {
            let existingAssignments = existingAssignmentsCache[assignment.applicationId] ?? []

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
        }

        Logger.shared.info("Validation complete: \(validatedAssignments.count) new assignments to create, \(assignments.count - validatedAssignments.count) skipped")
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
