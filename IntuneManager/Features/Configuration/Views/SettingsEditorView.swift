import SwiftUI
import Combine

struct SettingsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsEditorViewModel()

    let templateId: String
    let platform: DeviceManagementConfigurationPolicy.Platform
    @Binding var configuredSettings: [DeviceManagementConfigurationSetting]

    @State private var searchText = ""
    @State private var selectedCategory: String? = nil
    @State private var expandedCategories: Set<String> = []
    @State private var settingValues: [String: SettingValue] = [:]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search settings...", text: $searchText)
                            .textFieldStyle(.plain)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)

                    if !viewModel.categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                CategoryChip(
                                    title: "All",
                                    isSelected: selectedCategory == nil,
                                    action: { selectedCategory = nil }
                                )

                                ForEach(viewModel.categories, id: \.self) { category in
                                    CategoryChip(
                                        title: category,
                                        isSelected: selectedCategory == category,
                                        action: { selectedCategory = category }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Theme.Colors.secondaryBackground)

                Divider()

                // Settings list
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Loading settings...")
                    Spacer()
                } else if filteredSettings.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Settings" : "No Results",
                        systemImage: searchText.isEmpty ? "slider.horizontal.3" : "magnifyingglass",
                        description: Text(searchText.isEmpty ?
                            "No settings available for this template" :
                            "No settings match '\(searchText)'")
                    )
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16, pinnedViews: .sectionHeaders) {
                            ForEach(groupedSettings.keys.sorted(), id: \.self) { category in
                                if let settings = groupedSettings[category] {
                                    SettingsCategorySection(
                                        category: category,
                                        settings: settings,
                                        isExpanded: expandedCategories.contains(category),
                                        settingValues: $settingValues,
                                        onToggle: {
                                            toggleCategory(category)
                                        }
                                    )
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Configure Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applySettings()
                        dismiss()
                    }
                    .disabled(settingValues.isEmpty)
                }
            }
            .task {
                await viewModel.loadSettings(for: templateId)
                // Initialize with existing configured settings
                for setting in configuredSettings {
                    if let value = extractValueFromSetting(setting) {
                        settingValues[setting.settingInstance.settingDefinitionId] = value
                    }
                }
            }
        }
    }

    private var filteredSettings: [DeviceManagementConfigurationSettingDefinition] {
        var settings = viewModel.availableSettings

        if let category = selectedCategory {
            settings = settings.filter { $0.categoryId == category }
        }

        if !searchText.isEmpty {
            settings = settings.filter { setting in
                setting.displayName?.localizedCaseInsensitiveContains(searchText) ?? false ||
                setting.description?.localizedCaseInsensitiveContains(searchText) ?? false ||
                setting.name?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }

        return settings
    }

    private var groupedSettings: [String: [DeviceManagementConfigurationSettingDefinition]] {
        Dictionary(grouping: filteredSettings) { setting in
            setting.categoryId ?? "General"
        }
    }

    private func toggleCategory(_ category: String) {
        if expandedCategories.contains(category) {
            expandedCategories.remove(category)
        } else {
            expandedCategories.insert(category)
        }
    }

    private func extractValueFromSetting(_ setting: DeviceManagementConfigurationSetting) -> SettingValue? {
        let instance = setting.settingInstance

        if let choiceValue = instance.choiceSettingValue {
            return .choice(choiceValue.value)
        } else if let simpleValue = instance.simpleSettingValue {
            switch simpleValue.value {
            case .string(let val):
                return .string(val)
            case .integer(let val):
                return .integer(val)
            case .boolean(let val):
                return .boolean(val)
            case .double(let val):
                return .double(val)
            }
        }

        return nil
    }

    private func applySettings() {
        configuredSettings = settingValues.compactMap { (definitionId, value) -> DeviceManagementConfigurationSetting? in
            var settingInstance: DeviceManagementConfigurationSettingInstance

            switch value {
            case .string(let stringValue):
                settingInstance = DeviceManagementConfigurationSettingInstance(
                    settingDefinitionId: definitionId,
                    simpleSettingValue: SimpleSettingValue(value: .string(stringValue))
                )
            case .integer(let intValue):
                settingInstance = DeviceManagementConfigurationSettingInstance(
                    settingDefinitionId: definitionId,
                    simpleSettingValue: SimpleSettingValue(value: .integer(intValue))
                )
            case .boolean(let boolValue):
                settingInstance = DeviceManagementConfigurationSettingInstance(
                    settingDefinitionId: definitionId,
                    simpleSettingValue: SimpleSettingValue(value: .boolean(boolValue))
                )
            case .double(let doubleValue):
                settingInstance = DeviceManagementConfigurationSettingInstance(
                    settingDefinitionId: definitionId,
                    simpleSettingValue: SimpleSettingValue(value: .double(doubleValue))
                )
            case .choice(let choiceValue):
                settingInstance = DeviceManagementConfigurationSettingInstance(
                    settingDefinitionId: definitionId,
                    choiceSettingValue: ChoiceSettingValue(value: choiceValue, children: nil)
                )
            }

            return DeviceManagementConfigurationSetting(
                id: nil,
                settingInstance: settingInstance
            )
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsCategorySection: View {
    let category: String
    let settings: [DeviceManagementConfigurationSettingDefinition]
    let isExpanded: Bool
    @Binding var settingValues: [String: SettingValue]
    let onToggle: () -> Void

    var body: some View {
        Section {
            if isExpanded {
                ForEach(settings) { setting in
                    SettingRowView(
                        setting: setting,
                        value: Binding(
                            get: { settingValues[setting.id] },
                            set: { settingValues[setting.id] = $0 }
                        )
                    )
                }
            }
        } header: {
            HStack {
                Text(category)
                    .font(.headline)

                Spacer()

                Text("\(settings.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .imageScale(.small)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    onToggle()
                }
            }
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

struct SettingRowView: View {
    let setting: DeviceManagementConfigurationSettingDefinition
    @Binding var value: SettingValue?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(setting.displayName ?? setting.name ?? "Unnamed Setting")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if let description = setting.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                SettingControlView(
                    setting: setting,
                    value: $value
                )
            }

            if let helpText = setting.helpText {
                HStack {
                    Image(systemName: "info.circle")
                        .imageScale(.small)
                    Text(helpText)
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(value != nil ? Color.accentColor.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
}

struct SettingControlView: View {
    let setting: DeviceManagementConfigurationSettingDefinition
    @Binding var value: SettingValue?

    var body: some View {
        Group {
            switch setting.uxBehavior {
            case .toggle:
                Toggle("", isOn: Binding(
                    get: {
                        if case .boolean(let boolValue) = value {
                            return boolValue
                        }
                        return false
                    },
                    set: { newValue in
                        value = .boolean(newValue)
                    }
                ))
                .toggleStyle(.switch)

            case .dropdown:
                if let options = setting.options {
                    Picker("", selection: Binding(
                        get: {
                            if case .choice(let choiceValue) = value {
                                return choiceValue
                            }
                            return options.first?.itemId ?? ""
                        },
                        set: { newValue in
                            value = .choice(newValue)
                        }
                    )) {
                        ForEach(options, id: \.itemId) { option in
                            Text(option.displayName ?? option.name ?? "")
                                .tag(option.itemId ?? "")
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

            case .smallTextBox, .largeTextBox:
                TextField("Value", text: Binding(
                    get: {
                        if case .string(let stringValue) = value {
                            return stringValue
                        }
                        return ""
                    },
                    set: { newValue in
                        value = .string(newValue)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: setting.uxBehavior == .largeTextBox ? 300 : 200)

            default:
                // Default text field for unknown types
                TextField("Value", text: Binding(
                    get: {
                        switch value {
                        case .string(let val):
                            return val
                        case .integer(let val):
                            return String(val)
                        case .boolean(let val):
                            return String(val)
                        case .double(let val):
                            return String(val)
                        case .choice(let val):
                            return val
                        case nil:
                            return ""
                        }
                    },
                    set: { newValue in
                        // Try to parse as appropriate type
                        if let intValue = Int(newValue) {
                            value = .integer(intValue)
                        } else if let doubleValue = Double(newValue) {
                            value = .double(doubleValue)
                        } else if newValue.lowercased() == "true" {
                            value = .boolean(true)
                        } else if newValue.lowercased() == "false" {
                            value = .boolean(false)
                        } else {
                            value = .string(newValue)
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 200)
            }
        }
    }
}

enum SettingValue {
    case string(String)
    case integer(Int)
    case boolean(Bool)
    case double(Double)
    case choice(String)
}

@MainActor
final class SettingsEditorViewModel: ObservableObject {
    @Published var availableSettings: [DeviceManagementConfigurationSettingDefinition] = []
    @Published var categories: [String] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let configurationService = ConfigurationService.shared

    func loadSettings(for templateId: String) async {
        isLoading = true
        error = nil

        do {
            availableSettings = try await configurationService.fetchSettingDefinitionsForTemplate(
                templateId: templateId
            )

            // Extract unique categories
            let uniqueCategories = Set(availableSettings.compactMap { $0.categoryId })
            categories = Array(uniqueCategories).sorted()

            Logger.shared.info("Loaded \(availableSettings.count) settings", category: .ui)
        } catch {
            self.error = error
            Logger.shared.error("Failed to load settings: \(error)", category: .network)
        }

        isLoading = false
    }
}

#Preview {
    @Previewable @State var settings: [DeviceManagementConfigurationSetting] = []

    return SettingsEditorView(
        templateId: "test-template-id",
        platform: .iOS,
        configuredSettings: $settings
    )
}