import Foundation
import Combine

@MainActor
class DeviceListViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var searchText = ""
    @Published var isLoading = false
    
    private let deviceService = DeviceService.shared
    
    var filteredDevices: [Device] {
        if searchText.isEmpty {
            return devices
        }
        return deviceService.searchDevices(query: searchText)
    }
    
    func loadDevices() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            devices = try await deviceService.fetchDevices()
        } catch {
            // Handle error
        }
    }
}