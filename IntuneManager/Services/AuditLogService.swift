import Foundation
import SwiftData
import Combine

@MainActor
final class AuditLogService: ObservableObject {
    static let shared = AuditLogService()

    @Published var auditLogs: [AuditLog] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let graphClient: GraphAPIClient
    private let rateLimiter: RateLimiter

    private init() {
        self.graphClient = GraphAPIClient.shared
        self.rateLimiter = RateLimiter.shared
    }

    func fetchRecentAuditLogs(hoursAgo: Int = 72, limit: Int = 50) async {
        isLoading = true
        errorMessage = nil

        do {
            // Calculate the date filter (72 hours ago)
            let startDate = Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: Date()) ?? Date()
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]
            let filterDate = dateFormatter.string(from: startDate)

            let endpoint = "/deviceManagement/auditEvents"
            let parameters = [
                "$filter": "activityDateTime ge \(filterDate)",
                "$top": String(limit),
                "$orderby": "activityDateTime desc"
            ]

            let fetchedLogs: [AuditLog] = try await graphClient.getAllPagesForModels(endpoint, parameters: parameters)

            await MainActor.run {
                self.auditLogs = fetchedLogs
                self.isLoading = false
            }

            Logger.shared.info("Fetched \(fetchedLogs.count) audit logs", category: .network)

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            Logger.shared.error("Failed to fetch audit logs: \(error.localizedDescription)", category: .network)
        }
    }

    func fetchAllAuditLogsFields(hoursAgo: Int = 72, limit: Int = 50) async {
        isLoading = true
        errorMessage = nil

        do {
            // Calculate the date filter (72 hours ago)
            let startDate = Calendar.current.date(byAdding: .hour, value: -hoursAgo, to: Date()) ?? Date()
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withInternetDateTime]
            let filterDate = dateFormatter.string(from: startDate)

            let endpoint = "/deviceManagement/auditEvents"
            let parameters = [
                "$filter": "activityDateTime ge \(filterDate)",
                "$top": String(limit),
                "$orderby": "activityDateTime desc",
                "$select": "id,displayName,componentName,activity,activityDateTime,activityType,activityOperationType,activityResult,correlationId,category,actor,resources",
                "$expand": "resources"
            ]

            let fetchedLogs: [AuditLog] = try await graphClient.getAllPagesForModels(endpoint, parameters: parameters)

            await MainActor.run {
                self.auditLogs = fetchedLogs
                self.isLoading = false
            }

            Logger.shared.info("Fetched \(fetchedLogs.count) audit logs with expanded fields", category: .network)

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            Logger.shared.error("Failed to fetch audit logs: \(error.localizedDescription)", category: .network)
        }
    }

    func getAuditLog(by id: String) -> AuditLog? {
        return auditLogs.first { $0.id == id }
    }

    func clearAuditLogs() {
        auditLogs = []
        errorMessage = nil
    }
}

