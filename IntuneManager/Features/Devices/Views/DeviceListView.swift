import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    @State private var isSyncing = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                ProgressView("Loading devices...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(viewModel.filteredDevices) { device in
                    NavigationLink(destination: DeviceDetailView(device: device)) {
                        DeviceRowView(device: device)
                    }
                }
                .searchable(text: $viewModel.searchText)
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: syncDevices) {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Label("Sync All", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isSyncing)
                .help("Sync devices, applications, and groups from Intune")
            }
        }
        .task {
            await viewModel.loadDevices()
        }
    }

    private func syncDevices() {
        Task {
            isSyncing = true
            defer { isSyncing = false }
            await appState.syncAll()
            await viewModel.loadDevices()
        }
    }
}

struct DeviceRowView: View {
    let device: Device

    var body: some View {
        HStack {
            Image(systemName: "laptopcomputer")
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                Text(device.deviceName)
                    .font(.headline)
                Text(device.userDisplayName ?? "Unknown User")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(device.complianceState.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.systemColor(named: device.complianceState.displayColor).opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}