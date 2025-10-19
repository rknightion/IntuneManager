import SwiftUI

// MARK: - iOS VPP Settings Section
struct IOSVppSettingsSection: View {
    @Binding var settings: IOSVppAppAssignmentSettings
    let onShowHelp: (String, String, String?) -> Void
    @State private var hoveredSetting: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("iOS VPP App Settings", systemImage: "iphone")
                .font(.headline)

            // License Type
            SettingRow(
                title: "License type",
                description: AssignmentSettingDescription.iosVppDescriptions["useDeviceLicensing"]?.description ?? "",
                hoveredSetting: $hoveredSetting,
                settingKey: "useDeviceLicensing",
                onShowHelp: onShowHelp
            ) {
                HStack(spacing: 8) {
                    Button(action: { settings.useDeviceLicensing = false }) {
                        Label {
                            Text("User")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.useDeviceLicensing == false ? .accentColor : .secondary)

                    Button(action: { settings.useDeviceLicensing = true }) {
                        Label {
                            Text("Device")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "desktopcomputer")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.useDeviceLicensing == true ? .accentColor : .secondary)
                }
            }

            // VPN Configuration
            SettingRow(
                title: "VPN",
                description: AssignmentSettingDescription.iosVppDescriptions["vpnConfiguration"]?.description ?? "",
                hoveredSetting: $hoveredSetting,
                settingKey: "vpnConfiguration",
                onShowHelp: onShowHelp
            ) {
                // TODO: Implement VPN profile picker once VPN profiles are loaded
                Menu {
                    Button("None") {
                        settings.vpnConfigurationId = nil
                    }
                    Divider()
                    Text("No VPN profiles available")
                        .foregroundColor(.secondary)
                } label: {
                    HStack {
                        Text(settings.vpnConfigurationId ?? "None")
                            .foregroundColor(settings.vpnConfigurationId == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            // Boolean Settings
            Group {
                ToggleSettingRow(
                    title: "Prevent automatic app updates",
                    description: AssignmentSettingDescription.iosVppDescriptions["preventAutoAppUpdate"]?.description ?? "",
                    isOn: $settings.preventAutoAppUpdate,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "preventAutoAppUpdate",
                    onShowHelp: onShowHelp
                )

                ToggleSettingRow(
                    title: "Uninstall on device removal",
                    description: AssignmentSettingDescription.iosVppDescriptions["uninstallOnDeviceRemoval"]?.description ?? "",
                    isOn: $settings.uninstallOnDeviceRemoval,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "uninstallOnDeviceRemoval",
                    onShowHelp: onShowHelp
                )

                ToggleSettingRow(
                    title: "Install as removable",
                    description: AssignmentSettingDescription.iosVppDescriptions["isRemovable"]?.description ?? "",
                    isOn: $settings.isRemovable,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "isRemovable",
                    onShowHelp: onShowHelp
                )

                ToggleSettingRow(
                    title: "Prevent iCloud app backup",
                    description: AssignmentSettingDescription.iosVppDescriptions["preventManagedAppBackup"]?.description ?? "",
                    isOn: $settings.preventManagedAppBackup,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "preventManagedAppBackup",
                    onShowHelp: onShowHelp
                )
            }
        }
    }
}

// MARK: - iOS LOB Settings Section
struct IOSLobSettingsSection: View {
    @Binding var settings: IOSLobAppAssignmentSettings
    let onShowHelp: (String, String, String?) -> Void
    @State private var hoveredSetting: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("iOS Line-of-Business App Settings", systemImage: "iphone")
                .font(.headline)

            // VPN Configuration
            SettingRow(
                title: "VPN",
                description: "Automatically connect to VPN when this app launches",
                hoveredSetting: $hoveredSetting,
                settingKey: "vpnConfiguration",
                onShowHelp: onShowHelp
            ) {
                Menu {
                    Button("None") {
                        settings.vpnConfigurationId = nil
                    }
                } label: {
                    HStack {
                        Text(settings.vpnConfigurationId ?? "None")
                            .foregroundColor(.secondary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                }
            }

            // Boolean Settings
            Group {
                ToggleSettingRow(
                    title: "Uninstall on device removal",
                    description: "Automatically uninstall when device is removed from management",
                    isOn: $settings.uninstallOnDeviceRemoval,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "uninstallOnDeviceRemoval",
                    onShowHelp: onShowHelp
                )

                ToggleSettingRow(
                    title: "Install as removable",
                    description: "Allow users to uninstall this app",
                    isOn: $settings.isRemovable,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "isRemovable",
                    onShowHelp: onShowHelp
                )

                ToggleSettingRow(
                    title: "Prevent iCloud app backup",
                    description: "Prevent app data from being backed up to iCloud",
                    isOn: $settings.preventManagedAppBackup,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "preventManagedAppBackup",
                    onShowHelp: onShowHelp
                )
            }
        }
    }
}

// MARK: - macOS VPP Settings Section
struct MacOSVppSettingsSection: View {
    @Binding var settings: MacOSVppAppAssignmentSettings
    let onShowHelp: (String, String, String?) -> Void
    @State private var hoveredSetting: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("macOS VPP App Settings", systemImage: "macbook")
                .font(.headline)

            // License Type
            SettingRow(
                title: "License type",
                description: "Choose between user-based or device-based licensing",
                hoveredSetting: $hoveredSetting,
                settingKey: "useDeviceLicensing",
                onShowHelp: onShowHelp
            ) {
                HStack(spacing: 8) {
                    Button(action: { settings.useDeviceLicensing = false }) {
                        Label {
                            Text("User")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "person.fill")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.useDeviceLicensing == false ? .accentColor : .secondary)

                    Button(action: { settings.useDeviceLicensing = true }) {
                        Label {
                            Text("Device")
                                .font(.caption)
                        } icon: {
                            Image(systemName: "desktopcomputer")
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(settings.useDeviceLicensing == true ? .accentColor : .secondary)
                }
            }

            // Boolean Settings
            Group {
                ToggleSettingRow(
                    title: "Prevent automatic app updates",
                    description: "Prevent the app from updating automatically",
                    isOn: $settings.preventAutoAppUpdate,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "preventAutoAppUpdate",
                    onShowHelp: onShowHelp
                )

                ToggleSettingRow(
                    title: "Uninstall on device removal",
                    description: "Automatically uninstall when device is removed from management",
                    isOn: $settings.uninstallOnDeviceRemoval,
                    hoveredSetting: $hoveredSetting,
                    settingKey: "uninstallOnDeviceRemoval",
                    onShowHelp: onShowHelp
                )
            }
        }
    }
}

// MARK: - macOS LOB (DMG/PKG) Settings Section
// Note: All macOS LOB-based apps (DMG, PKG, LOB) use the same assignment settings.
// Detection rules, version detection, and minimum OS are properties of the APP itself during creation, not assignment.
struct MacOSLobSettingsSection: View {
    @Binding var settings: MacOSLobAppAssignmentSettings
    let onShowHelp: (String, String, String?) -> Void
    @State private var hoveredSetting: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("macOS Line-of-Business App Settings", systemImage: "macbook")
                .font(.headline)

            Text("Settings apply to DMG, PKG, and LOB apps")
                .font(.caption)
                .foregroundColor(.secondary)

            // Uninstall on Device Removal
            ToggleSettingRow(
                title: "Uninstall on device removal",
                description: "Automatically uninstall when device is removed from management",
                isOn: $settings.uninstallOnDeviceRemoval,
                hoveredSetting: $hoveredSetting,
                settingKey: "uninstallOnDeviceRemoval",
                onShowHelp: onShowHelp
            )

            // Informational note about app creation properties
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("App Creation Properties")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text("Detection rules, version detection, and minimum OS version are configured when creating or updating the app itself, not during assignment.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(6)
            }
        }
    }
}

// MARK: - Android Managed Store Settings Section
struct AndroidSettingsSection: View {
    @Binding var settings: AndroidManagedStoreAppAssignmentSettings
    let onShowHelp: (String, String, String?) -> Void
    @State private var hoveredSetting: String?
    @State private var trackIdInput: String = ""
    @State private var showingTrackInput: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Android App Settings", systemImage: "smartphone")
                .font(.headline)

            // Auto Update Mode
            SettingRow(
                title: "App update priority",
                description: AssignmentSettingDescription.androidDescriptions["autoUpdateMode"]?.description ?? "",
                hoveredSetting: $hoveredSetting,
                settingKey: "autoUpdateMode",
                onShowHelp: onShowHelp
            ) {
                Picker("", selection: $settings.autoUpdateMode) {
                    ForEach(AndroidManagedStoreAppAssignmentSettings.AutoUpdateMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
            }

            // Show description for selected update mode
            if settings.autoUpdateMode != .default {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text(settings.autoUpdateMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(6)
            }

            Divider()

            // App Tracks
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("App Version Tracks", systemImage: "arrow.triangle.branch")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Button(action: {
                        let description = AssignmentSettingDescription.androidDescriptions["androidManagedStoreAppTrackIds"]
                        if let desc = description {
                            onShowHelp(desc.title, desc.description, desc.helpUrl)
                        }
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .opacity(hoveredSetting == "androidManagedStoreAppTrackIds" ? 1 : 0.3)
                    .help("View documentation")

                    Spacer()
                }
                .onHover { hovering in
                    if hovering {
                        hoveredSetting = "androidManagedStoreAppTrackIds"
                    } else if hoveredSetting == "androidManagedStoreAppTrackIds" {
                        hoveredSetting = nil
                    }
                }

                Text("Enable specific app tracks for staged rollouts and beta testing")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Track chips
                if let tracks = settings.androidManagedStoreAppTrackIds, !tracks.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(tracks, id: \.self) { track in
                            HStack(spacing: 4) {
                                Text(track)
                                    .font(.caption)
                                Button(action: {
                                    settings.androidManagedStoreAppTrackIds?.removeAll { $0 == track }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                                .buttonStyle(.plain)
                                .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(12)
                        }
                    }
                } else {
                    Text("No tracks selected (uses default production track)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }

                // Add track button
                Button(action: {
                    showingTrackInput = true
                }) {
                    Label("Add Track", systemImage: "plus.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showingTrackInput) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add App Track")
                            .font(.headline)

                        Text("Common tracks: production, beta, alpha, internal")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Track ID", text: $trackIdInput)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Cancel") {
                                showingTrackInput = false
                                trackIdInput = ""
                            }
                            .keyboardShortcut(.escape)

                            Spacer()

                            Button("Add") {
                                if !trackIdInput.isEmpty {
                                    if settings.androidManagedStoreAppTrackIds == nil {
                                        settings.androidManagedStoreAppTrackIds = []
                                    }
                                    if !settings.androidManagedStoreAppTrackIds!.contains(trackIdInput) {
                                        settings.androidManagedStoreAppTrackIds?.append(trackIdInput)
                                    }
                                    trackIdInput = ""
                                    showingTrackInput = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(trackIdInput.isEmpty)
                        }
                    }
                    .padding()
                    .frame(width: 300)
                }
            }
            .padding(8)
            .background(hoveredSetting == "androidManagedStoreAppTrackIds" ? Color.gray.opacity(0.05) : Color.clear)
            .cornerRadius(6)
        }
    }
}

// MARK: - Windows Settings Section
struct WindowsSettingsSection: View {
    @Binding var settings: WindowsAppAssignmentSettings
    let onShowHelp: (String, String, String?) -> Void
    @State private var hoveredSetting: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Windows App Settings", systemImage: "pc")
                .font(.headline)

            // Delivery Optimization
            SettingRow(
                title: "Delivery optimization priority",
                description: "Control the priority of app downloads",
                hoveredSetting: $hoveredSetting,
                settingKey: "deliveryOptimization",
                onShowHelp: onShowHelp
            ) {
                Picker("", selection: $settings.deliveryOptimizationPriority) {
                    ForEach(WindowsAppAssignmentSettings.DeliveryOptimizationPriority.allCases, id: \.self) { priority in
                        Text(priority.displayName).tag(priority)
                    }
                }
                .pickerStyle(.menu)
            }

            // Notifications
            SettingRow(
                title: "Notifications",
                description: "Control which notifications users see during app installation",
                hoveredSetting: $hoveredSetting,
                settingKey: "notifications",
                onShowHelp: onShowHelp
            ) {
                Picker("", selection: $settings.notifications) {
                    ForEach(WindowsAppAssignmentSettings.NotificationSetting.allCases, id: \.self) { notification in
                        Text(notification.displayName).tag(notification)
                    }
                }
                .pickerStyle(.menu)
            }

            // Restart Settings
            VStack(alignment: .leading, spacing: 8) {
                Label("Restart Settings", systemImage: "arrow.clockwise")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if settings.restartSettings == nil {
                    Button("Configure Restart Settings") {
                        settings.restartSettings = WindowsAppAssignmentSettings.RestartSettings()
                    }
                    .buttonStyle(.bordered)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Grace period:")
                            TextField("", value: Binding(
                                get: { settings.restartSettings?.gracePeriodInMinutes ?? 1440 },
                                set: { settings.restartSettings?.gracePeriodInMinutes = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(maxWidth: 100)
                            Text("minutes")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)

                        Button("Remove Restart Settings") {
                            settings.restartSettings = nil
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

// MARK: - Assignment Filters Section
struct AssignmentFiltersSection: View {
    @Binding var groupSettings: GroupAssignmentSettings
    let appType: Application.AppType

    @ObservedObject private var filterService = AssignmentFilterService.shared
    @State private var showingFilterPicker = false

    private var selectedFilter: AssignmentFilter? {
        filterService.filter(withId: groupSettings.assignmentFilterId)
    }

    private var filterModeBinding: Binding<AssignmentFilterMode> {
        Binding(
            get: { groupSettings.assignmentFilterMode ?? .include },
            set: { newValue in
                groupSettings.assignmentFilterMode = newValue
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Label("Assignment Filters", systemImage: "line.horizontal.3.decrease.circle")
                .font(.headline)

            Text("Target this group with an Intune assignment filter.")
                .font(.caption)
                .foregroundColor(.secondary)

            if filterService.isLoading && filterService.filters.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.75)
                    Text("Loading filters…")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let filter = selectedFilter {
                filterSummary(filter)

                Picker("Filter Mode", selection: filterModeBinding) {
                    Text("Include").tag(AssignmentFilterMode.include)
                    Text("Exclude").tag(AssignmentFilterMode.exclude)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 220)

                HStack(spacing: 12) {
                    Button {
                        showingFilterPicker = true
                    } label: {
                        Label("Change Filter", systemImage: "arrow.triangle.2.circlepath")
                    }

                    Button(role: .destructive) {
                        clearSelection()
                    } label: {
                        Label("Remove Filter", systemImage: "trash")
                    }
                }
                .buttonStyle(.bordered)
            } else {
                Button {
                    showingFilterPicker = true
                } label: {
                    Label("Add Filter", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Text("No filter selected. The assignment will target all devices in the group.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .task {
            await filterService.fetchFilters()
        }
        .sheet(isPresented: $showingFilterPicker) {
            AssignmentFilterPickerView(
                appType: appType,
                selectedFilterId: groupSettings.assignmentFilterId
            ) { filter in
                groupSettings.assignmentFilterId = filter.id
                if groupSettings.assignmentFilterMode == nil {
                    groupSettings.assignmentFilterMode = .include
                }
            }
            .frame(minWidth: 360, minHeight: 420)
        }
    }

    private func filterSummary(_ filter: AssignmentFilter) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "line.horizontal.3.decrease.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(filter.displayName)
                        .font(.headline)
                    Text(filter.platform.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if !filter.rule.isEmpty {
                Text(filter.rule)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(Color.gray.opacity(0.08))
                    .cornerRadius(6)
            }

            if let description = filter.filterDescription, !description.isEmpty {
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(8)
    }

    private func clearSelection() {
        groupSettings.assignmentFilterId = nil
        groupSettings.assignmentFilterMode = nil
    }
}

// MARK: - Reusable Setting Components
struct SettingRow<Content: View>: View {
    let title: String
    let description: String
    @Binding var hoveredSetting: String?
    let settingKey: String
    let onShowHelp: (String, String, String?) -> Void
    let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Button(action: {
                        // Try iOS descriptions first, then macOS, then Windows
                        let description = AssignmentSettingDescription.iosVppDescriptions[settingKey]
                            ?? AssignmentSettingDescription.macosDescriptions[settingKey]
                            ?? AssignmentSettingDescription.windowsDescriptions[settingKey]

                        if let desc = description {
                            onShowHelp(desc.title, desc.description, desc.helpUrl)
                        }
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .opacity(hoveredSetting == settingKey ? 1 : 0.3)
                    .help("View documentation")
                }

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content()
                .frame(maxWidth: 200)
        }
        .padding(8)
        .background(hoveredSetting == settingKey ? Color.gray.opacity(0.05) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            hoveredSetting = hovering ? settingKey : nil
        }
    }
}

struct ToggleSettingRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    @Binding var hoveredSetting: String?
    let settingKey: String
    let onShowHelp: (String, String, String?) -> Void

    var body: some View {
        SettingRow(
            title: title,
            description: description,
            hoveredSetting: $hoveredSetting,
            settingKey: settingKey,
            onShowHelp: onShowHelp
        ) {
            HStack {
                Picker("", selection: $isOn) {
                    Text("Yes").tag(true)
                    Text("No").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }
}
