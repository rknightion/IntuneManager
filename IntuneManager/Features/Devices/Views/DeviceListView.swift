import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    @State private var isSyncing = false
    @State private var showFilters = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading && viewModel.devices.isEmpty {
                ProgressView("Loading devices...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Filter bar
                if showFilters {
                    DeviceFiltersView(viewModel: viewModel)
                        .padding()
                        .background(Theme.Colors.secondaryBackground)
                        .border(Color.secondary.opacity(0.2), width: 0.5)
                }

                // Device count and sync all button
                HStack {
                    Text("\(viewModel.filteredDevices.count) of \(viewModel.devices.count) devices")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        Task {
                            isSyncing = true
                            await viewModel.syncAllVisibleDevices()
                            isSyncing = false
                        }
                    }) {
                        if isSyncing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(0.8)
                        } else {
                            Label("Sync Visible Devices", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption)
                        }
                    }
                    .disabled(isSyncing || viewModel.filteredDevices.isEmpty)
                    .help("Trigger Intune sync for all visible devices")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                List(viewModel.filteredDevices) { device in
                    NavigationLink(destination: DeviceDetailView(device: device)) {
                        DeviceRowView(device: device, viewModel: viewModel)
                    }
                }
                .searchable(text: $viewModel.searchText, prompt: "Search devices...")
            }
        }
        .navigationTitle("Devices")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                // Filter toggle button
                Button(action: { showFilters.toggle() }) {
                    Label("Filters", systemImage: "line.horizontal.3.decrease.circle")
                        .symbolVariant(showFilters ? .fill : .none)
                }
                .help("Toggle device filters")
                .overlay(alignment: .topTrailing) {
                    if viewModel.activeFilterCount > 0 {
                        Text("\(viewModel.activeFilterCount)")
                            .font(.caption2)
                            .padding(2)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }

                // Refresh all button
                Button(action: refreshData) {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else {
                        Label("Refresh All", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isSyncing)
                .help("Refresh devices, applications, and groups from Microsoft Intune")
            }
        }
        .task {
            viewModel.setAppState(appState)
            await viewModel.loadDevices()
        }
    }

    private func refreshData() {
        Task {
            isSyncing = true
            defer { isSyncing = false }
            await appState.refreshAll()
            await viewModel.loadDevices()
        }
    }
}

struct DeviceRowView: View {
    let device: Device
    @ObservedObject var viewModel: DeviceListViewModel
    @State private var isSyncing = false

    var body: some View {
        HStack {
            Image(systemName: deviceIcon)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceName)
                    .font(.headline)
                HStack(spacing: 4) {
                    Text(device.userDisplayName ?? "Unknown User")
                    Text("•")
                    Text(device.operatingSystem)
                    if let osVersion = device.osVersion {
                        Text(osVersion)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    if device.isEncrypted {
                        Label("Encrypted", systemImage: "lock.shield.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    if device.isSupervised {
                        Label("Supervised", systemImage: "person.fill.checkmark")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    if device.azureADRegistered {
                        Label("Azure AD", systemImage: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                }
            }

            Spacer()

            // Sync button
            Button(action: {
                Task {
                    await viewModel.syncDevice(device)
                }
            }) {
                if viewModel.syncingDeviceIds.contains(device.id) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.accentColor)
                }
            }
            .buttonStyle(.borderless)
            .help("Sync this device with Intune")

            // Compliance badge
            Text(device.complianceState.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.systemColor(named: device.complianceState.displayColor).opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private var deviceIcon: String {
        switch device.operatingSystem.lowercased() {
        case let os where os.contains("ios") || os.contains("iphone"):
            return "iphone"
        case let os where os.contains("ipad"):
            return "ipad"
        case let os where os.contains("mac"):
            return "laptopcomputer"
        case let os where os.contains("windows"):
            return "pc"
        case let os where os.contains("android"):
            return "smartphone"
        default:
            return "desktopcomputer"
        }
    }
}

// MARK: - Filters View

struct DeviceFiltersView: View {
    @ObservedObject var viewModel: DeviceListViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // OS Filter
                Menu {
                    ForEach(viewModel.availableOperatingSystems, id: \.self) { os in
                        Button(action: { viewModel.selectedOS = os }) {
                            if viewModel.selectedOS == os {
                                Label(os, systemImage: "checkmark")
                            } else {
                                Text(os)
                            }
                        }
                    }
                } label: {
                    DeviceFilterChip(title: "OS", value: viewModel.selectedOS == "All" ? nil : viewModel.selectedOS)
                }

                // Ownership Filter
                Menu {
                    Button("Any", action: { viewModel.selectedOwnership = nil })
                    ForEach(Device.Ownership.allCases, id: \.self) { ownership in
                        Button(ownership.displayName) {
                            viewModel.selectedOwnership = ownership
                        }
                    }
                } label: {
                    DeviceFilterChip(title: "Ownership", value: viewModel.selectedOwnership?.displayName)
                }

                // Compliance Filter
                Menu {
                    Button("Any", action: { viewModel.selectedCompliance = nil })
                    ForEach(Device.ComplianceState.allCases, id: \.self) { compliance in
                        Button(compliance.displayName) {
                            viewModel.selectedCompliance = compliance
                        }
                    }
                } label: {
                    DeviceFilterChip(title: "Compliance", value: viewModel.selectedCompliance?.displayName)
                }

                // Boolean Filters
                FilterToggle(title: "Intune Registered", value: $viewModel.isIntuneRegistered)
                FilterToggle(title: "Supervised", value: $viewModel.isSupervised)
                FilterToggle(title: "Encrypted", value: $viewModel.isEncrypted)
                FilterToggle(title: "Azure AD Registered", value: $viewModel.isAzureADRegistered)

                // Category Filter
                if !viewModel.availableCategories.isEmpty && viewModel.availableCategories.count > 1 {
                    Menu {
                        ForEach(viewModel.availableCategories, id: \.self) { category in
                            Button(action: {
                                viewModel.selectedCategory = category == "All" ? nil : category
                            }) {
                                if (category == "All" && viewModel.selectedCategory == nil) ||
                                   viewModel.selectedCategory == category {
                                    Label(category, systemImage: "checkmark")
                                } else {
                                    Text(category)
                                }
                            }
                        }
                    } label: {
                        DeviceFilterChip(title: "Category", value: viewModel.selectedCategory)
                    }
                }

                // Model Filter
                if viewModel.availableModels.count > 2 { // More than just "All" and one other
                    Menu {
                        ForEach(viewModel.availableModels, id: \.self) { model in
                            Button(action: {
                                viewModel.selectedModel = model == "All" ? nil : model
                            }) {
                                if (model == "All" && viewModel.selectedModel == nil) ||
                                   viewModel.selectedModel == model {
                                    Label(model, systemImage: "checkmark")
                                } else {
                                    Text(model)
                                }
                            }
                        }
                    } label: {
                        DeviceFilterChip(title: "Model", value: viewModel.selectedModel)
                    }
                }

                // Manufacturer Filter
                if viewModel.availableManufacturers.count > 2 {
                    Menu {
                        ForEach(viewModel.availableManufacturers, id: \.self) { manufacturer in
                            Button(action: {
                                viewModel.selectedManufacturer = manufacturer == "All" ? nil : manufacturer
                            }) {
                                if (manufacturer == "All" && viewModel.selectedManufacturer == nil) ||
                                   viewModel.selectedManufacturer == manufacturer {
                                    Label(manufacturer, systemImage: "checkmark")
                                } else {
                                    Text(manufacturer)
                                }
                            }
                        }
                    } label: {
                        DeviceFilterChip(title: "Manufacturer", value: viewModel.selectedManufacturer)
                    }
                }

                // Clear All Filters
                if viewModel.activeFilterCount > 0 {
                    Button(action: { viewModel.clearFilters() }) {
                        Label("Clear All", systemImage: "xmark.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
}

struct DeviceFilterChip: View {
    let title: String
    let value: String?

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            if let value = value {
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            } else {
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(value != nil ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
        .cornerRadius(6)
    }
}

struct FilterToggle: View {
    let title: String
    @Binding var value: Bool?

    var body: some View {
        Menu {
            Button("Any", action: { value = nil })
            Button("Yes", action: { value = true })
            Button("No", action: { value = false })
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let val = value {
                    Image(systemName: val ? "checkmark.circle.fill" : "xmark.circle")
                        .font(.caption)
                        .foregroundColor(val ? .green : .red)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(value != nil ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.1))
            .cornerRadius(6)
        }
    }
}