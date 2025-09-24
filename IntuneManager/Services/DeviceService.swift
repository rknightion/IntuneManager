import Foundation
import Combine

// MARK: - Helper Types for DeviceService

fileprivate struct WipeBody: Encodable, Sendable {
    let keepEnrollmentData: Bool
    let keepUserData: Bool
}

@MainActor
final class DeviceService: ObservableObject {
    static let shared = DeviceService()

    @Published var devices: [Device] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastSync: Date?

    private let apiClient = GraphAPIClient.shared
    private let dataStore = LocalDataStore.shared
    private let cacheManager = CacheManager.shared

    private init() {
        devices = dataStore.fetchDevices()
    }

    // MARK: - Public Methods

    func fetchDevices(forceRefresh: Bool = false) async throws -> [Device] {
        // Use CacheManager to determine if we should use cache
        if cacheManager.canUseCache(for: .devices) && !forceRefresh {
            let cached = dataStore.fetchDevices()
            if !cached.isEmpty {
                devices = cached
                Logger.shared.debug("Using cached devices (\(cached.count) items)", category: .data)
                return cached
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let endpoint = "/deviceManagement/managedDevices"
            let parameters = [
                "$select": "id,deviceName,model,manufacturer,operatingSystem,osVersion,serialNumber,enrolledDateTime,lastSyncDateTime,complianceState,managementState,managedDeviceOwnerType,userPrincipalName,userDisplayName,userId,emailAddress,isEncrypted,isSupervised,azureADDeviceId,azureADRegistered,deviceCategory,deviceEnrollmentType,phoneNumber,notes,ethernetMacAddress,wiFiMacAddress,freeStorageSpaceInBytes,totalStorageSpaceInBytes,jailBroken,managedDeviceName,partnerReportedThreatState,imei,meid,udid,iccid,subscriberCarrier,physicalMemoryInBytes,processorArchitecture,managementCertificateExpirationDate,exchangeAccessState,exchangeAccessStateReason,exchangeLastSuccessfulSyncDateTime,remoteAssistanceSessionUrl,autopilotEnrolled,requireUserEnrollmentApproval,lostModeState,activationLockBypassCode,deviceRegistrationState,managementAgent,deviceType,chassisType,joinType,skuFamily,skuNumber,complianceGracePeriodExpirationDateTime,androidSecurityPatchLevel,easActivated,easDeviceId,easActivationDateTime,aadRegistered,windowsActiveMalwareCount,windowsRemediatedMalwareCount,bootstrapTokenEscrowed,deviceFirmwareConfigurationInterfaceManaged",
                "$orderby": "deviceName"
                // Removed filter to get ALL device types including Windows, Android, etc.
            ]

            let fetchedDevices: [Device] = try await apiClient.getAllPagesForModels(endpoint, parameters: parameters)

            // Update the data store first to maintain context consistency
            dataStore.replaceDevices(with: fetchedDevices)

            // Now update the in-memory collection with fresh data from the store
            // This ensures we're working with models attached to the current context
            self.devices = dataStore.fetchDevices()
            self.lastSync = Date()

            cacheManager.updateMetadata(for: .devices, recordCount: fetchedDevices.count)

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

        let device: Device = try await apiClient.getModel(endpoint)
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

        let headers = ["Content-Type": "application/json"]
        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: EmptyBody(), headers: headers)

        Logger.shared.info("Sync initiated for device: \(device.deviceName)")

        // Refresh device data
        _ = try await fetchDevice(id: device.id)
    }

    func retireDevice(_ device: Device) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/retire"

        let headers = ["Content-Type": "application/json"]
        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: EmptyBody(), headers: headers)

        Logger.shared.info("Retire initiated for device: \(device.deviceName)")
    }

    func wipeDevice(_ device: Device, keepEnrollmentData: Bool = false, keepUserData: Bool = false) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/wipe"

        let body = WipeBody(keepEnrollmentData: keepEnrollmentData, keepUserData: keepUserData)

        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: body, headers: nil)

        Logger.shared.warning("Wipe initiated for device: \(device.deviceName)")
    }

    func shutdownDevice(_ device: Device) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/shutDown"

        let headers = ["Content-Type": "application/json"]
        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: EmptyBody(), headers: headers)

        Logger.shared.info("Shutdown initiated for device: \(device.deviceName)")
    }

    func restartDevice(_ device: Device) async throws {
        let endpoint = "/deviceManagement/managedDevices/\(device.id)/rebootNow"

        let headers = ["Content-Type": "application/json"]
        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: EmptyBody(), headers: headers)

        Logger.shared.info("Restart initiated for device: \(device.deviceName)")
    }

    // MARK: - Batch Operations

    func performBatchSync(_ devices: [Device]) async throws {
        let requests = devices.map { device in
            BatchRequest(
                method: "POST",
                url: "/deviceManagement/managedDevices/\(device.id)/syncDevice",
                body: EmptyBody(),
                headers: ["Content-Type": "application/json"]
            )
        }

        let _: [BatchResponse<EmptyResponse>] = try await apiClient.batchModels(requests)

        Logger.shared.info("Batch sync initiated for \(devices.count) devices")
    }

    // MARK: - Private Methods

    func hydrateFromStore() {
        let cachedDevices = dataStore.fetchDevices()
        if !cachedDevices.isEmpty {
            devices = cachedDevices
        }
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
