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
        HStack(alignment: .top, spacing: 0) {
            // Group List Sidebar
            GroupListSidebar(
                groups: selectedGroups,
                selectedGroupId: $selectedGroupId,
                groupSettings: groupSettings
            )
            .frame(width: 250)
            .frame(maxHeight: .infinity)

            Divider()

            // Settings Panel
            ScrollView {
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
                    .frame(maxWidth: 600, alignment: .topLeading)
                    .padding(.horizontal)
                } else {
                    EmptyGroupSettingsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity)
        }
        .frame(minWidth: 700, maxWidth: 900)
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

            // Use a custom button group instead of segmented picker
            HStack(spacing: 8) {
                ForEach(Assignment.AssignmentIntent.allCases.filter { $0 != .availableWithoutEnrollment }, id: \.self) { option in
                    Button(action: {
                        intent = option
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: option.icon)
                                .font(.title2)
                                .foregroundColor(intent == option ? .white : .accentColor)
                            Text(option.displayName)
                                .font(.caption)
                                .foregroundColor(intent == option ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(intent == option ? Color.accentColor : Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Intent Description
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(intent.detailedDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

// MARK: - Help Text View
struct HelpTextView: View {
    let title: String
    let description: String
    let helpUrl: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(title, systemImage: "questionmark.circle.fill")
                    .font(.headline)
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape)
            }
            .padding()

            Divider()

            // Help content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Main description
                    Text(description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Additional context
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Key Points", systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.accentColor)

                        // Break down the description into bullet points if it's long
                        if description.count > 150 {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(extractKeyPoints(from: description), id: \.self) { point in
                                    HStack(alignment: .top, spacing: 8) {
                                        Text("•")
                                            .foregroundColor(.secondary)
                                        Text(point)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                            }
                            .padding(.leading)
                        }
                    }
                    .padding()
                    .background(Color.accentColor.opacity(0.05))
                    .cornerRadius(8)

                    // Learn more button
                    if let urlString = helpUrl, let url = URL(string: urlString) {
                        Divider()

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Want to learn more?")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: {
                                openURL(url)
                                dismiss()
                            }) {
                                Label("View Microsoft Documentation", systemImage: "arrow.up.right.square")
                                    .font(.caption)
                            }
                            .buttonStyle(.link)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 400)
    }

    private func extractKeyPoints(from text: String) -> [String] {
        // Extract key points from the description
        var points: [String] = []

        // Split by common delimiters
        let sentences = text.components(separatedBy: ". ")
        for sentence in sentences where !sentence.isEmpty {
            let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 20 && trimmed.count < 150 {
                points.append(trimmed + (sentence.hasSuffix(".") ? "" : "."))
            }
        }

        // If we got too many points, limit to 3-4 most important
        if points.count > 4 {
            points = Array(points.prefix(4))
        }

        return points
    }
}