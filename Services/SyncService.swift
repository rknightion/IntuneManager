import Foundation

@MainActor
class SyncService {
    static let shared = SyncService()
    
    private let deviceService = DeviceService.shared
    private let appService = ApplicationService.shared
    private let groupService = GroupService.shared
    
    private init() {}
    
    func performFullSync() async throws {
        async let devices = deviceService.fetchDevices(forceRefresh: true)
        async let apps = appService.fetchApplications(forceRefresh: true)
        async let groups = groupService.fetchGroups(forceRefresh: true)
        
        _ = try await (devices, apps, groups)
        
        Logger.shared.info("Full sync completed")
    }
}