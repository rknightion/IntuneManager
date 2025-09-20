import Foundation

@MainActor
class SyncService {
    static let shared = SyncService()
    
    private let deviceService = DeviceService.shared
    private let appService = ApplicationService.shared
    private let groupService = GroupService.shared
    
    private init() {}
    
    func performFullSync() async throws {
        _ = try await deviceService.fetchDevices(forceRefresh: true)
        _ = try await appService.fetchApplications(forceRefresh: true)
        _ = try await groupService.fetchGroups(forceRefresh: true)

        Logger.shared.info("Full sync completed")
    }
}
