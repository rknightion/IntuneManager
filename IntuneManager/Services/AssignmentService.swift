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
            currentOperation: "Preparing assignments..."
        )

        Logger.shared.info("Starting bulk assignment: \(assignments.count) operations")

        // Process assignments in batches
        let batches = assignments.chunked(into: maxConcurrentAssignments)
        var completedAssignments: [Assignment] = []
        var failedAssignments: [Assignment] = []

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

        // Create batch requests for Graph API
        let requests = assignments.map { assignment in
            createBatchRequest(for: assignment)
        }

        // Execute batch request
        let responses: [BatchResponse<AppAssignment>] = try await apiClient.batchModels(requests)

        // Process responses
        for (index, response) in responses.enumerated() {
            let assignment = assignments[index]

            if response.status >= 200 && response.status < 300 {
                assignment.status = .completed
                assignment.completedDate = Date()
                successful.append(assignment)
                Logger.shared.info("Assignment successful: \(assignment.applicationName) -> \(assignment.groupName)")
            } else {
                assignment.status = .failed
                assignment.errorMessage = "HTTP Status: \(response.status)"

                if assignment.retryCount < retryLimit {
                    // Retry failed assignment
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
                    failed.append(assignment)
                    Logger.shared.error("Assignment failed after \(retryLimit) attempts: \(assignment.applicationName) -> \(assignment.groupName)")
                }
            }
        }

        return (successful, failed)
    }

    private func createBatchRequest(for assignment: Assignment) -> BatchRequest {
        let targetType = assignment.targetType
        let appAssignment = AppAssignment(
            id: assignment.id,
            intent: AppAssignment.AssignmentIntent(rawValue: assignment.intent.rawValue) ?? .required,
            target: AppAssignment.AssignmentTarget(
                type: targetType,
                groupId: targetType.requiresGroupId ? assignment.groupId : nil,
                groupName: targetType.requiresGroupId ? assignment.groupName : nil,
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
            body: appAssignment
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
            pending: pending,
            successRate: total > 0 ? Double(completed) / Double(total) * 100 : 0
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
    let successRate: Double
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

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
