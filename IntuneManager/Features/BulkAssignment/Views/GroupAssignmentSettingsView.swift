import SwiftUI

struct GroupAssignmentSettingsView: View {
    @Binding var groupSettings: [GroupAssignmentSettings]
    let selectedApplications: Set<Application>
    let selectedGroups: Set<DeviceGroup>
    @State private var selectedGroupId: String?
    @State private var showingDocumentation = false
    @State private var documentationUrl: URL?

    // Determine the primary app type from selected applications
    var primaryAppType: Application.AppType {
        // Group apps by type and take the most common
        let appTypes = selectedApplications.map { $0.appType }
        let typeCount = Dictionary(grouping: appTypes, by: { $0 }).mapValues { $0.count }
        return typeCount.max(by: { $0.value < $1.value })?.key ?? .unknown
    }

    var commonPlatforms: Set<Application.DevicePlatform> {
        guard !selectedApplications.isEmpty else { return [] }
        let platformSets = selectedApplications.map { $0.supportedPlatforms }
        guard let firstSet = platformSets.first else { return [] }
        return platformSets.dropFirst().reduce(firstSet) { result, platforms in
            result.intersection(platforms)
        }
    }

    var body: some View {
        #if os(macOS)
        HStack(spacing: 0) {
            // Group List
            GroupListSidebar(
                groups: selectedGroups,
                selectedGroupId: $selectedGroupId,
                groupSettings: groupSettings
            )
            .frame(width: 300)

            Divider()

            // Settings Panel
            if let selectedGroup = selectedGroups.first(where: { $0.id == selectedGroupId }),
               let index = groupSettings.firstIndex(where: { $0.groupId == selectedGroup.id }) {
                GroupSettingsPanel(
                    settings: $groupSettings[index],
                    appType: primaryAppType,
                    platforms: commonPlatforms,
                    onShowDocumentation: { url in
                        documentationUrl = url
                        showingDocumentation = true
                    }
                )
                .frame(minWidth: 500, maxWidth: .infinity)
            } else {
                EmptyGroupSettingsView()
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 800, idealWidth: 900, maxWidth: 1200)
        .onAppear {
            // Select the first group if none selected
            if selectedGroupId == nil, let firstGroup = selectedGroups.first {
                selectedGroupId = firstGroup.id
            }
        }
        .sheet(isPresented: $showingDocumentation) {
            if let url = documentationUrl {
                DocumentationWebView(url: url)
            }
        }
        #else
        // For iOS/iPadOS, use a NavigationSplitView
        NavigationSplitView {
            // Group List
            GroupListSidebar(
                groups: selectedGroups,
                selectedGroupId: $selectedGroupId,
                groupSettings: groupSettings
            )
        } detail: {
            // Settings Panel
            if let selectedGroup = selectedGroups.first(where: { $0.id == selectedGroupId }),
               let index = groupSettings.firstIndex(where: { $0.groupId == selectedGroup.id }) {
                GroupSettingsPanel(
                    settings: $groupSettings[index],
                    appType: primaryAppType,
                    platforms: commonPlatforms,
                    onShowDocumentation: { url in
                        documentationUrl = url
                        showingDocumentation = true
                    }
                )
            } else {
                EmptyGroupSettingsView()
            }
        }
        .onAppear {
            // Select the first group if none selected
            if selectedGroupId == nil, let firstGroup = selectedGroups.first {
                selectedGroupId = firstGroup.id
            }
        }
        .sheet(isPresented: $showingDocumentation) {
            if let url = documentationUrl {
                DocumentationWebView(url: url)
            }
        }
        #endif
    }
}

// MARK: - Group List Sidebar
struct GroupListSidebar: View {
    let groups: Set<DeviceGroup>
    @Binding var selectedGroupId: String?
    let groupSettings: [GroupAssignmentSettings]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Label("Groups", systemImage: "person.3")
                    .font(.headline)
                Spacer()
                Text("\(groups.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            .padding()

            Divider()

            // Group List
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(groups.sorted(by: { $0.displayName < $1.displayName })) { group in
                        GroupSettingsRowView(
                            group: group,
                            isSelected: selectedGroupId == group.id,
                            hasCustomSettings: hasCustomSettings(for: group.id),
                            onSelect: {
                                selectedGroupId = group.id
                            }
                        )
                    }
                }
                .padding(8)
            }
        }
        .background(Theme.Colors.secondaryBackground)
    }

    func hasCustomSettings(for groupId: String) -> Bool {
        guard let settings = groupSettings.first(where: { $0.groupId == groupId }) else {
            return false
        }
        // Check if settings differ from defaults
        return settings.settings.iosVppSettings?.useDeviceLicensing ?? false ||
               settings.settings.iosVppSettings?.uninstallOnDeviceRemoval ?? false ||
               settings.settings.iosVppSettings?.preventAutoAppUpdate ?? false ||
               settings.settings.iosVppSettings?.vpnConfigurationId != nil
    }
}

struct GroupSettingsRowView: View {
    let group: DeviceGroup
    let isSelected: Bool
    let hasCustomSettings: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: group.isBuiltInAssignmentTarget ? "building.2" : "person.3")
                .foregroundColor(.accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.system(.body))
                    .lineLimit(1)

                if let memberCount = group.memberCount {
                    Text("\(memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if hasCustomSettings {
                Image(systemName: "gearshape.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .help("Has custom settings")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(6)
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Settings Panel
struct GroupSettingsPanel: View {
    @Binding var settings: GroupAssignmentSettings
    let appType: Application.AppType
    let platforms: Set<Application.DevicePlatform>
    let onShowDocumentation: (URL) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                GroupSettingsHeader(groupName: settings.groupName, appType: appType)

                Divider()

                // Assignment Intent
                AssignmentIntentSection(intent: $settings.settings.intent)

                // App Type Specific Settings
                Group {
                    switch appType {
                    case .iosVppApp:
                        IOSVppSettingsSection(
                            settings: Binding(
                                get: {
                                    settings.settings.iosVppSettings ?? IOSVppAppAssignmentSettings()
                                },
                                set: {
                                    settings.settings.iosVppSettings = $0
                                }
                            ),
                            onShowDocumentation: onShowDocumentation
                        )
                        .onAppear {
                            if settings.settings.iosVppSettings == nil {
                                settings.settings.iosVppSettings = IOSVppAppAssignmentSettings()
                            }
                        }

                    case .iosLobApp:
                        IOSLobSettingsSection(
                            settings: Binding(
                                get: {
                                    settings.settings.iosLobSettings ?? IOSLobAppAssignmentSettings()
                                },
                                set: {
                                    settings.settings.iosLobSettings = $0
                                }
                            ),
                            onShowDocumentation: onShowDocumentation
                        )
                        .onAppear {
                            if settings.settings.iosLobSettings == nil {
                                settings.settings.iosLobSettings = IOSLobAppAssignmentSettings()
                            }
                        }

                    case .macOSVppApp:
                        MacOSVppSettingsSection(
                            settings: Binding(
                                get: {
                                    settings.settings.macosVppSettings ?? MacOSVppAppAssignmentSettings()
                                },
                                set: {
                                    settings.settings.macosVppSettings = $0
                                }
                            ),
                            onShowDocumentation: onShowDocumentation
                        )
                        .onAppear {
                            if settings.settings.macosVppSettings == nil {
                                settings.settings.macosVppSettings = MacOSVppAppAssignmentSettings()
                            }
                        }

                    case .macOSDmgApp:
                        MacOSDmgSettingsSection(
                            settings: Binding(
                                get: {
                                    settings.settings.macosDmgSettings ?? MacOSDmgAppAssignmentSettings()
                                },
                                set: {
                                    settings.settings.macosDmgSettings = $0
                                }
                            ),
                            onShowDocumentation: onShowDocumentation
                        )
                        .onAppear {
                            if settings.settings.macosDmgSettings == nil {
                                settings.settings.macosDmgSettings = MacOSDmgAppAssignmentSettings()
                            }
                        }

                    case .windowsWebApp, .win32LobApp, .winGetApp:
                        WindowsSettingsSection(
                            settings: Binding(
                                get: {
                                    settings.settings.windowsSettings ?? WindowsAppAssignmentSettings()
                                },
                                set: {
                                    settings.settings.windowsSettings = $0
                                }
                            ),
                            onShowDocumentation: onShowDocumentation
                        )
                        .onAppear {
                            if settings.settings.windowsSettings == nil {
                                settings.settings.windowsSettings = WindowsAppAssignmentSettings()
                            }
                        }

                    default:
                        Text("No specific settings available for this app type")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }

                // Assignment Filters Section
                AssignmentFiltersSection(settings: $settings.settings)
            }
            .padding()
        }
    }
}

struct GroupSettingsHeader: View {
    let groupName: String
    let appType: Application.AppType

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gearshape.2")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("Assignment Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            Text("Configure how apps will be assigned to **\(groupName)**")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Label(appType.displayName, systemImage: appType.icon)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
}

// MARK: - Assignment Intent Section
struct AssignmentIntentSection: View {
    @Binding var intent: Assignment.AssignmentIntent

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Assignment Mode", systemImage: "arrow.down.square")
                .font(.headline)

            Picker("", selection: $intent) {
                ForEach(Assignment.AssignmentIntent.allCases, id: \.self) { intent in
                    HStack {
                        Image(systemName: intent.icon)
                        Text(intent.displayName)
                    }
                    .tag(intent)
                }
            }
            .pickerStyle(.segmented)

            // Intent Description
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(intent.detailedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.accentColor.opacity(0.05))
            .cornerRadius(6)
        }
    }
}

// MARK: - Empty State
struct EmptyGroupSettingsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Select a group to configure settings")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Each group can have unique assignment settings")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Documentation Web View
struct DocumentationWebView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Microsoft Documentation", systemImage: "book")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    // Dismissing is handled by the sheet
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            // WebView would go here - placeholder for now
            VStack {
                Text("Opening: \(url.absoluteString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()

                Spacer()

                Text("Documentation would be displayed here")
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .frame(width: 800, height: 600)
    }
}