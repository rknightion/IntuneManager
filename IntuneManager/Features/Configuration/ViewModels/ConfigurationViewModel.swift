import Foundation
import SwiftUI
import Combine

@MainActor
class ConfigurationViewModel: ObservableObject {
    @Published var profiles: [ConfigurationProfile] = []
    @Published var templates: [ConfigurationTemplate] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""

    private let configurationService = ConfigurationService.shared

    init() {
        // Subscribe to configuration service updates
        profiles = configurationService.profiles
        templates = configurationService.templates
    }

    func loadProfiles(forceRefresh: Bool = false) async {
        isLoading = true
        error = nil

        do {
            let fetchedProfiles = try await configurationService.fetchConfigurationProfiles(forceRefresh: forceRefresh)
            profiles = fetchedProfiles
            Logger.shared.info("Loaded \(fetchedProfiles.count) configuration profiles", category: .ui)
        } catch {
            self.error = error
            Logger.shared.error("Failed to load configuration profiles: \(error)", category: .ui)
        }

        isLoading = false
    }

    func loadTemplates(forceRefresh: Bool = false) async {
        isLoading = true
        error = nil

        do {
            let fetchedTemplates = try await configurationService.fetchConfigurationTemplates(forceRefresh: forceRefresh)
            templates = fetchedTemplates
            Logger.shared.info("Loaded \(fetchedTemplates.count) configuration templates", category: .ui)
        } catch {
            self.error = error
            Logger.shared.error("Failed to load configuration templates: \(error)", category: .ui)
        }

        isLoading = false
    }

    func searchProfiles(_ query: String) -> [ConfigurationProfile] {
        if query.isEmpty {
            return profiles
        }
        return profiles.filter { profile in
            profile.displayName.localizedCaseInsensitiveContains(query) ||
            (profile.profileDescription?.localizedCaseInsensitiveContains(query) ?? false) ||
            (profile.templateDisplayName?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    func profilesForPlatform(_ platform: ConfigurationProfile.PlatformType) -> [ConfigurationProfile] {
        profiles.filter { $0.platformType == platform }
    }

    func profilesForType(_ type: ConfigurationProfile.ProfileType) -> [ConfigurationProfile] {
        profiles.filter { $0.profileType == type }
    }

    func templatesForPlatform(_ platform: String) -> [ConfigurationTemplate] {
        templates.filter { $0.platformTypes.contains(platform) }
    }

    func updateProfileAssignments(
        _ profile: ConfigurationProfile,
        assignments: [ConfigurationAssignment]
    ) async {
        do {
            let isSettingsCatalog = profile.profileType == .settingsCatalog
            try await configurationService.updateProfileAssignments(
                profileId: profile.id,
                assignments: assignments,
                isSettingsCatalog: isSettingsCatalog
            )

            // Update local copy
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index].assignments = assignments
                profiles[index].isAssigned = !assignments.isEmpty
            }

            Logger.shared.info("Successfully updated assignments for profile: \(profile.displayName)", category: .ui)
        } catch {
            self.error = error
            Logger.shared.error("Failed to update profile assignments: \(error)", category: .ui)
        }
    }
}
