import Foundation
import Combine

@MainActor
class SyncService {
    static let shared = SyncService()
    
    private let deviceService = DeviceService.shared
    private let appService = ApplicationService.shared
    private let groupService = GroupService.shared
    
    private init() {}
    
    func performFullSync() async throws {
        async let devicesTask = deviceService.fetchDevices(forceRefresh: true)
        async let appsTask = appService.fetchApplications(forceRefresh: true)
        async let groupsTask = groupService.fetchGroups(forceRefresh: true)
        _ = try await devicesTask
        _ = try await appsTask
        _ = try await groupsTask
        await AssignmentFilterService.shared.fetchFilters(forceRefresh: true)

        Logger.shared.info("Full sync completed")
    }
}
