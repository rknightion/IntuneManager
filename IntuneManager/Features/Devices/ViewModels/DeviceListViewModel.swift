import Foundation
import Combine

@MainActor
class DeviceListViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var searchText = ""
    @Published var isLoading = false
    @Published var syncingDeviceIds: Set<String> = []

    // Filter states
    @Published var selectedOS: String = "All"
    @Published var selectedOwnership: Device.Ownership?
    @Published var selectedCompliance: Device.ComplianceState?
    @Published var isIntuneRegistered: Bool?
    @Published var isSupervised: Bool?
    @Published var isEncrypted: Bool?
    @Published var isAzureADRegistered: Bool?
    @Published var selectedCategory: String?
    @Published var selectedModel: String?
    @Published var selectedManufacturer: String?

    private let deviceService = DeviceService.shared
    private var appState: AppState?

    var availableOperatingSystems: [String] {
        var systems = Set<String>()
        systems.insert("All")
        devices.forEach { systems.insert($0.operatingSystem) }
        return Array(systems).sorted()
    }

    var availableCategories: [String] {
        var categories = Set<String>()
        categories.insert("All")
        devices.compactMap { $0.deviceCategory }.forEach { categories.insert($0) }
        return Array(categories).sorted()
    }

    var availableModels: [String] {
        var models = Set<String>()
        models.insert("All")
        devices.compactMap { $0.model }.forEach { models.insert($0) }
        return Array(models).sorted()
    }

    var availableManufacturers: [String] {
        var manufacturers = Set<String>()
        manufacturers.insert("All")
        devices.compactMap { $0.manufacturer }.forEach { manufacturers.insert($0) }
        return Array(manufacturers).sorted()
    }

    var filteredDevices: [Device] {
        var result = devices

        // Apply search filter
        if !searchText.isEmpty {
            result = deviceService.searchDevices(query: searchText)
        }

        // Apply OS filter
        if selectedOS != "All" {
            result = result.filter { $0.operatingSystem == selectedOS }
        }

        // Apply ownership filter
        if let ownership = selectedOwnership {
            result = result.filter { $0.ownership == ownership }
        }

        // Apply compliance filter
        if let compliance = selectedCompliance {
            result = result.filter { $0.complianceState == compliance }
        }

        // Apply Intune registered filter (assuming managed state means Intune registered)
        if let intuneRegistered = isIntuneRegistered {
            if intuneRegistered {
                result = result.filter { $0.managementState == .managed }
            } else {
                result = result.filter { $0.managementState != .managed }
            }
        }

        // Apply supervised filter
        if let supervised = isSupervised {
            result = result.filter { $0.isSupervised == supervised }
        }

        // Apply encrypted filter
        if let encrypted = isEncrypted {
            result = result.filter { $0.isEncrypted == encrypted }
        }

        // Apply Azure AD registered filter
        if let azureRegistered = isAzureADRegistered {
            result = result.filter { $0.azureADRegistered == azureRegistered }
        }

        // Apply category filter
        if let category = selectedCategory, category != "All" {
            result = result.filter { $0.deviceCategory == category }
        }

        // Apply model filter
        if let model = selectedModel, model != "All" {
            result = result.filter { $0.model == model }
        }

        // Apply manufacturer filter
        if let manufacturer = selectedManufacturer, manufacturer != "All" {
            result = result.filter { $0.manufacturer == manufacturer }
        }

        return result
    }

    func loadDevices() async {
        isLoading = true
        defer { isLoading = false }

        do {
            devices = try await deviceService.fetchDevices()
        } catch {
            Logger.shared.error("Failed to load devices: \(error)", category: .ui)
        }
    }

    func syncDevice(_ device: Device) async {
        syncingDeviceIds.insert(device.id)
        defer { syncingDeviceIds.remove(device.id) }

        do {
            try await deviceService.syncDevice(device)
            Logger.shared.info("Successfully synced device: \(device.deviceName)", category: .ui)
        } catch {
            Logger.shared.error("Failed to sync device \(device.deviceName): \(error)", category: .ui)
            if case GraphAPIError.forbidden = error {
                appState?.handlePermissionError(operation: "sync device", resource: "device")
            }
        }
    }

    func syncAllVisibleDevices() async {
        let devicesToSync = filteredDevices

        do {
            try await deviceService.performBatchSync(devicesToSync)
            Logger.shared.info("Successfully initiated sync for \(devicesToSync.count) devices", category: .ui)
            // Refresh device data after sync
            await loadDevices()
        } catch {
            Logger.shared.error("Failed to sync devices: \(error)", category: .ui)
            if case GraphAPIError.forbidden = error {
                appState?.handlePermissionError(operation: "batch sync devices", resource: "devices")
            }
        }
    }

    func clearFilters() {
        selectedOS = "All"
        selectedOwnership = nil
        selectedCompliance = nil
        isIntuneRegistered = nil
        isSupervised = nil
        isEncrypted = nil
        isAzureADRegistered = nil
        selectedCategory = nil
        selectedModel = nil
        selectedManufacturer = nil
        searchText = ""
    }

    var activeFilterCount: Int {
        var count = 0
        if selectedOS != "All" { count += 1 }
        if selectedOwnership != nil { count += 1 }
        if selectedCompliance != nil { count += 1 }
        if isIntuneRegistered != nil { count += 1 }
        if isSupervised != nil { count += 1 }
        if isEncrypted != nil { count += 1 }
        if isAzureADRegistered != nil { count += 1 }
        if selectedCategory != nil && selectedCategory != "All" { count += 1 }
        if selectedModel != nil && selectedModel != "All" { count += 1 }
        if selectedManufacturer != nil && selectedManufacturer != "All" { count += 1 }
        return count
    }

    func setAppState(_ state: AppState) {
        self.appState = state
    }
}