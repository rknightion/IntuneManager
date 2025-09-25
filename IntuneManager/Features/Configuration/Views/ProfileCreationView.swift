import SwiftUI
import Combine

struct ProfileCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileCreationViewModel()

    @State private var profileName = ""
    @State private var profileDescription = ""
    @State private var selectedPlatform: DeviceManagementConfigurationPolicy.Platform = .iOS
    @State private var selectedTechnology: DeviceManagementConfigurationPolicy.Technology = .mdm
    @State private var selectedTemplate: DeviceManagementConfigurationPolicyTemplate?
    @State private var searchText = ""
    @State private var showingSettings = false
    @State private var configuredSettings: [DeviceManagementConfigurationSetting] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Profile Name", text: $profileName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Description", text: $profileDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Configuration") {
                    Picker("Platform", selection: $selectedPlatform) {
                        ForEach(DeviceManagementConfigurationPolicy.Platform.allCases, id: \.self) { platform in
                            Text(platform.displayName).tag(platform)
                        }
                    }

                    Picker("Technology", selection: $selectedTechnology) {
                        ForEach(DeviceManagementConfigurationPolicy.Technology.allCases, id: \.self) { technology in
                            Text(technology.displayName).tag(technology)
                        }
                    }
                }

                Section("Template") {
                    if viewModel.isLoadingTemplates {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading templates...")
                                .foregroundColor(.secondary)
                        }
                    } else if viewModel.availableTemplates.isEmpty {
                        ContentUnavailableView(
                            "No Templates Available",
                            systemImage: "doc.text",
                            description: Text("No templates found for the selected platform")
                        )
                    } else {
                        TemplateSelectorView(
                            templates: filteredTemplates,
                            selectedTemplate: $selectedTemplate,
                            searchText: $searchText
                        )
                    }
                }

                if let template = selectedTemplate {
                    Section("Settings") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(template.description ?? "Configure settings for this profile")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: { showingSettings = true }) {
                                Label("Configure Settings", systemImage: "slider.horizontal.3")
                            }
                            .buttonStyle(.borderedProminent)

                            if !configuredSettings.isEmpty {
                                Text("\(configuredSettings.count) settings configured")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Configuration Profile")
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
                    Button("Create") {
                        Task {
                            await createProfile()
                        }
                    }
                    .disabled(!isFormValid)
                }
            }
            .sheet(isPresented: $showingSettings) {
                if let template = selectedTemplate {
                    SettingsEditorView(
                        templateId: template.id,
                        platform: selectedPlatform,
                        configuredSettings: $configuredSettings
                    )
                }
            }
            .task {
                await viewModel.loadTemplates(for: selectedPlatform)
            }
            .onChange(of: selectedPlatform) { _, newPlatform in
                Task {
                    selectedTemplate = nil
                    await viewModel.loadTemplates(for: newPlatform)
                }
            }
        }
    }

    private var filteredTemplates: [DeviceManagementConfigurationPolicyTemplate] {
        if searchText.isEmpty {
            return viewModel.availableTemplates
        }
        return viewModel.availableTemplates.filter { template in
            template.displayName.localizedCaseInsensitiveContains(searchText) ||
            (template.description?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    private var isFormValid: Bool {
        !profileName.isEmpty && selectedTemplate != nil
    }

    private func createProfile() async {
        guard let template = selectedTemplate else { return }

        await viewModel.createProfile(
            displayName: profileName,
            description: profileDescription.isEmpty ? nil : profileDescription,
            platform: selectedPlatform,
            technology: selectedTechnology,
            templateId: template.id,
            settings: configuredSettings
        )

        if viewModel.error == nil {
            dismiss()
        }
    }
}

struct TemplateSelectorView: View {
    let templates: [DeviceManagementConfigurationPolicyTemplate]
    @Binding var selectedTemplate: DeviceManagementConfigurationPolicyTemplate?
    @Binding var searchText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search templates...", text: $searchText)
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

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(templates) { template in
                        TemplateRowView(
                            template: template,
                            isSelected: selectedTemplate?.id == template.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTemplate = template
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }
}

struct TemplateRowView: View {
    let template: DeviceManagementConfigurationPolicyTemplate
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(template.displayName)
                        .font(.headline)

                    if let family = template.templateFamily {
                        Text(family.rawValue.replacingOccurrences(of: "endpointSecurity", with: ""))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }

                if let description = template.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    if let version = template.displayVersion {
                        Label(version, systemImage: "number")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    if let settingCount = template.settingTemplateCount {
                        Label("\(settingCount) settings", systemImage: "slider.horizontal.3")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

@MainActor
final class ProfileCreationViewModel: ObservableObject {
    @Published var availableTemplates: [DeviceManagementConfigurationPolicyTemplate] = []
    @Published var isLoadingTemplates = false
    @Published var error: Error?

    private let configurationService = ConfigurationService.shared

    func loadTemplates(for platform: DeviceManagementConfigurationPolicy.Platform) async {
        isLoadingTemplates = true
        error = nil

        do {
            availableTemplates = try await configurationService.fetchSettingsCatalogTemplates(
                platform: platform
            )
        } catch {
            self.error = error
            Logger.shared.error("Failed to load templates: \(error)", category: .network)
        }

        isLoadingTemplates = false
    }

    func createProfile(
        displayName: String,
        description: String?,
        platform: DeviceManagementConfigurationPolicy.Platform,
        technology: DeviceManagementConfigurationPolicy.Technology,
        templateId: String,
        settings: [DeviceManagementConfigurationSetting]
    ) async {
        error = nil

        do {
            let templateReference = ConfigurationPolicyTemplateReference(
                templateId: templateId,
                templateFamily: nil,
                templateDisplayName: nil,
                templateDisplayVersion: nil
            )

            _ = try await configurationService.createSettingsCatalogPolicy(
                displayName: displayName,
                description: description,
                platforms: [platform],
                technologies: [technology],
                templateReference: templateReference,
                settings: settings
            )

            Logger.shared.info("Successfully created configuration profile", category: .ui)
        } catch {
            self.error = error
            Logger.shared.error("Failed to create profile: \(error)", category: .network)
        }
    }
}

#Preview {
    ProfileCreationView()
}