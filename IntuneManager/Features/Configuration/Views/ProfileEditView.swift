import SwiftUI
import Combine

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ProfileEditViewModel()

    let profile: ConfigurationProfile

    @State private var profileName: String
    @State private var profileDescription: String
    @State private var configuredSettings: [DeviceManagementConfigurationSetting] = []
    @State private var showingSettings = false
    @State private var hasChanges = false
    @State private var isSaving = false

    init(profile: ConfigurationProfile) {
        self.profile = profile
        self._profileName = State(initialValue: profile.displayName)
        self._profileDescription = State(initialValue: profile.profileDescription ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Profile Name", text: $profileName)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: profileName) { _, _ in hasChanges = true }

                    TextField("Description", text: $profileDescription, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: profileDescription) { _, _ in hasChanges = true }
                }

                Section("Configuration") {
                    HStack {
                        Label("Platform", systemImage: profile.platformType.icon)
                        Spacer()
                        Text(profile.platformType.displayName)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Type", systemImage: profile.profileType.icon)
                        Spacer()
                        Text(profile.profileType.displayName)
                            .foregroundColor(.secondary)
                    }

                    if let templateName = profile.templateDisplayName {
                        HStack {
                            Label("Template", systemImage: "doc.text")
                            Spacer()
                            Text(templateName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("Metadata") {
                    HStack {
                        Label("Created", systemImage: "calendar")
                        Spacer()
                        Text(profile.createdDateTime, style: .date)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Last Modified", systemImage: "clock")
                        Spacer()
                        Text(profile.lastModifiedDateTime, style: .date)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("Version", systemImage: "number")
                        Spacer()
                        Text(String(profile.version))
                            .foregroundColor(.secondary)
                    }
                }

                if profile.profileType == .settingsCatalog && profile.templateId != nil {
                    Section("Settings") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Modify the settings for this profile")
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
                                    .onAppear { hasChanges = true }
                            }
                        }
                    }
                }

                Section("Assignments") {
                    if let assignments = profile.assignments, !assignments.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(assignments) { assignment in
                                HStack {
                                    Image(systemName: assignment.target.type.icon)
                                        .foregroundColor(.blue)
                                    Text(assignment.target.displayName)
                                    Spacer()
                                }
                            }
                        }
                    } else {
                        HStack {
                            Image(systemName: "person.3")
                                .foregroundColor(.secondary)
                            Text("No assignments configured")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Configuration Profile")
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
                    Button("Save") {
                        Task {
                            await saveChanges()
                        }
                    }
                    .disabled(!hasChanges || profileName.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showingSettings) {
                if let templateId = profile.templateId {
                    SettingsEditorView(
                        templateId: templateId,
                        platform: mapToConfigurationPolicyPlatform(profile.platformType),
                        configuredSettings: $configuredSettings
                    )
                }
            }
            .task {
                await loadProfileSettings()
            }
        }
    }

    private func mapToConfigurationPolicyPlatform(_ platform: ConfigurationProfile.PlatformType) -> DeviceManagementConfigurationPolicy.Platform {
        switch platform {
        case .iOS:
            return .iOS
        case .macOS:
            return .macOS
        case .android:
            return .android
        case .windows10:
            return .windows10
        case .androidEnterprise:
            return .androidEnterprise
        case .androidWorkProfile:
            return .androidWorkProfile
        }
    }

    private func loadProfileSettings() async {
        guard profile.profileType == .settingsCatalog else { return }

        // TODO: Load existing settings from the profile
        // This would require fetching the settings from the API
        // For now, we'll leave it empty
    }

    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        await viewModel.updateProfile(
            profile,
            displayName: profileName,
            description: profileDescription.isEmpty ? nil : profileDescription,
            settings: configuredSettings
        )

        if viewModel.error == nil {
            dismiss()
        }
    }
}

@MainActor
final class ProfileEditViewModel: ObservableObject {
    @Published var error: Error?
    private let configurationService = ConfigurationService.shared

    func updateProfile(
        _ profile: ConfigurationProfile,
        displayName: String,
        description: String?,
        settings: [DeviceManagementConfigurationSetting]
    ) async {
        error = nil

        do {
            // Update basic info
            let isSettingsCatalog = profile.profileType == .settingsCatalog
            try await configurationService.updateProfile(
                profileId: profile.id,
                displayName: displayName,
                description: description,
                isSettingsCatalog: isSettingsCatalog
            )

            // Update settings if it's a Settings Catalog profile and settings have changed
            if isSettingsCatalog && !settings.isEmpty {
                try await configurationService.updatePolicySettings(
                    policyId: profile.id,
                    settings: settings
                )
            }

            Logger.shared.info("Successfully updated profile: \(displayName)", category: .ui)
        } catch {
            self.error = error
            Logger.shared.error("Failed to update profile: \(error)", category: .network)
        }
    }
}

#Preview {
    ProfileEditView(
        profile: ConfigurationProfile(
            id: "test-id",
            displayName: "Test Profile",
            profileDescription: "Test Description",
            platformType: .iOS,
            profileType: .settingsCatalog,
            templateId: "template-id",
            templateDisplayName: "iOS Settings"
        )
    )
}