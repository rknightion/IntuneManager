import Foundation
import Combine
import SwiftData

@MainActor
class DeviceService: ObservableObject {
    static let shared = DeviceService()

    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastSync: Date?

    private let apiClient = GraphAPIClient.shared
    private let cache = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCachedDevices()
    }

    // MARK: - Public Methods

    func fetchDevices(forceRefresh: Bool = false) async throws -> [Device] {
        if !forceRefresh, let cachedDevices = getCachedDevices() {
            self.devices = cachedDevices
            return cachedDevices
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let endpoint = "/deviceManagement/managedDevices"
            let parameters = [
                "$select": "id,deviceName,model,manufacturer,operatingSystem,osVersion,serialNumber,enrolledDateTime,lastSyncDateTime,complianceState,managementState,ownership,userPrincipalName,userDisplayName,isEncrypted,isSupervised",
                "$orderby": "deviceName",
                "$filter": "operatingSystem eq 'macOS' or operatingSystem eq 'iOS' or operatingSystem eq 'iPadOS'"
            ]

            let fetchedDevices: [Device] = try await apiClient.getAllPages(endpoint, parameters: parameters)

            self.devices = fetchedDevices
            self.lastSync = Date()

            // Cache the devices
            await cacheDevices(fetchedDevices)

            Logger.shared.info("Fetched \(fetchedDevices.count) devices from Graph API")

            return fetchedDevices
        } catch {
            self.error = error
            Logger.shared.error("Failed to fetch devices: \(error)")
            throw error
        }
    }

    func fetchDevice(id: String) async throws -> Device {
        let endpoint = "/deviceManagement/managedDevices/\(id)"

        let device: Device = try await apiClient.get(endpoint)
        return device
    }

    func searchDevices(query: String) -> [Device] {
        guard !query.isEmpty else { return devices }

        return devices.filter { device in
            device.deviceName.localizedCaseInsensitiveContains(query) ||
            device.userDisplayName?.localizedCaseInsensitiveContains(query) == true ||
            device.serialNumber?.localizedCaseInsensitiveContains(query) == true ||
            device.userPrincipalName?.localizedCaseInsensitiveContains(query) == true
        }
    }

    func filterDevices(by criteria: FilterCriteria) -> [Device] {
        var filtered = devices

        if let os = criteria.operatingSystem {
            filtered = filtered.filter { $0.operatingSystem == os }
        }

        if let compliance = criteria.complianceState {
            filtered = filtered.filter { $0.complianceState == compliance }
        }

        if let ownership = criteria.ownership {
            filtered = filtered.filter { $0.ownership == ownership }
        }

        if let encrypted = criteria.isEncrypted {
            filtered = filtered.filter { $0.isEncrypted == encrypted }
        }

        return filtered
    }

    // MARK: - Device Actions

    func syncDevice(_ device: Device) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/syncDevice"

        try await apiClient.post(endpoint, body: EmptyBody(), headers: nil) as EmptyResponse

        Logger.shared.info("Sync initiated for device: \(device.deviceName)")

        // Refresh device data
        _ = try await fetchDevice(id: device.id)
    }

    func retireDevice(_ device: Device) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/retire"

        try await apiClient.post(endpoint, body: EmptyBody(), headers: nil) as EmptyResponse

        Logger.shared.info("Retire initiated for device: \(device.deviceName)")
    }

    func wipeDevice(_ device: Device, keepEnrollmentData: Bool = false, keepUserData: Bool = false) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/wipe"

        struct WipeBody: Encodable {
            let keepEnrollmentData: Bool
            let keepUserData: Bool
        }

        let body = WipeBody(keepEnrollmentData: keepEnrollmentData, keepUserData: keepUserData)

        try await apiClient.post(endpoint, body: body, headers: nil) as EmptyResponse

        Logger.shared.warning("Wipe initiated for device: \(device.deviceName)")
    }

    func shutdownDevice(_ device: Device) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/shutDown"

        try await apiClient.post(endpoint, body: EmptyBody(), headers: nil) as EmptyResponse

        Logger.shared.info("Shutdown initiated for device: \(device.deviceName)")
    }

    func restartDevice(_ device: Device) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/rebootNow"

        try await apiClient.post(endpoint, body: EmptyBody(), headers: nil) as EmptyResponse

        Logger.shared.info("Restart initiated for device: \(device.deviceName)")
    }

    // MARK: - Batch Operations

    func performBatchSync(_ devices: [Device]) async throws {
        let requests = devices.map { device in
            BatchRequest(
                method: "POST",
                url: "/deviceManagement/managedDevices/\(device.id)/syncDevice",
                body: EmptyBody()
            )
        }

        let _: [BatchResponse<EmptyResponse>] = try await apiClient.batch(requests)

        Logger.shared.info("Batch sync initiated for \(devices.count) devices")
    }

    // MARK: - Private Methods

    private func loadCachedDevices() {
        if let cachedDevices = getCachedDevices() {
            self.devices = cachedDevices
        }
    }

    private func getCachedDevices() -> [Device]? {
        return cache.getObject(forKey: "devices", type: [Device].self)
    }

    private func cacheDevices(_ devices: [Device]) async {
        cache.setObject(devices, forKey: "devices", expiration: .hours(1))
    }
}

// MARK: - Supporting Types

struct FilterCriteria {
    var operatingSystem: String?
    var complianceState: Device.ComplianceState?
    var ownership: Device.Ownership?
    var isEncrypted: Bool?
    var searchQuery: String?
}

// MARK: - Empty Body for POST requests
private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}