import Foundation
import Combine

@MainActor
final class ConfigurationService: ObservableObject {
    static let shared = ConfigurationService()

    @Published var profiles: [ConfigurationProfile] = []
    @Published var templates: [ConfigurationTemplate] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastFetchDate: Date?

    private let apiClient = GraphAPIClient.shared
    private let dataStore = LocalDataStore.shared
    private let rateLimiter = RateLimiter.shared

    private init() {
        loadCachedData()
    }

    // MARK: - Data Loading

    private func loadCachedData() {
        profiles = dataStore.fetchConfigurationProfiles()
        templates = dataStore.fetchConfigurationTemplates()
    }

    // MARK: - Configuration Profiles

    /// Fetch all configuration profiles
    func fetchConfigurationProfiles(forceRefresh: Bool = false) async throws -> [ConfigurationProfile] {
        if !forceRefresh && !profiles.isEmpty {
            return profiles
        }

        isLoading = true
        defer { isLoading = false }

        do {
            Logger.shared.info("Fetching configuration profiles from Graph API", category: .network)

            var allProfiles: [ConfigurationProfile] = []

            // Fetch device configurations
            let deviceConfigEndpoint = "/deviceManagement/deviceConfigurations"
            let deviceConfigResponse: DeviceConfigurationResponse = try await apiClient.getModel(
                deviceConfigEndpoint
            )

            for config in deviceConfigResponse.value {
                if let profile = config.toConfigurationProfile() {
                    // Fetch assignments for this profile
                    profile.assignments = try? await fetchAssignmentsForProfile(profileId: config.id)
                    profile.isAssigned = !(profile.assignments?.isEmpty ?? true)
                    allProfiles.append(profile)
                }
            }

            // Fetch settings catalog policies
            let settingsCatalogEndpoint = "/deviceManagement/configurationPolicies"
            do {
                let catalogResponse: SettingsCatalogPolicyResponse = try await apiClient.getModel(
                    settingsCatalogEndpoint
                )

                for policy in catalogResponse.value {
                    let profile = policy.toConfigurationProfile()
                    profile.assignments = try? await fetchAssignmentsForProfile(profileId: policy.id, isSettingsCatalog: true)
                    profile.isAssigned = !(profile.assignments?.isEmpty ?? true)
                    allProfiles.append(profile)
                }
            } catch {
                Logger.shared.warning("Failed to fetch settings catalog policies: \(error)", category: .network)
                // Continue with device configurations only
            }

            // Update local cache
            profiles = allProfiles
            dataStore.replaceConfigurationProfiles(allProfiles)
            lastFetchDate = Date()

            Logger.shared.info("Successfully fetched \(allProfiles.count) configuration profiles", category: .network)
            return allProfiles
        } catch {
            self.error = error
            Logger.shared.error("Failed to fetch configuration profiles: \(error)", category: .network)
            throw error
        }
    }

    /// Fetch assignments for a specific profile
    func fetchAssignmentsForProfile(profileId: String, isSettingsCatalog: Bool = false) async throws -> [ConfigurationAssignment] {
        let endpoint = isSettingsCatalog ?
            "/deviceManagement/configurationPolicies/\(profileId)/assignments" :
            "/deviceManagement/deviceConfigurations/\(profileId)/assignments"

        let response: ConfigurationAssignmentResponse = try await apiClient.getModel(
            endpoint
        )

        return response.value.map { $0.toConfigurationAssignment(profileId: profileId) }
    }

    // MARK: - Configuration Templates

    /// Fetch available configuration templates
    func fetchConfigurationTemplates(forceRefresh: Bool = false) async throws -> [ConfigurationTemplate] {
        if !forceRefresh && !templates.isEmpty {
            return templates
        }

        isLoading = true
        defer { isLoading = false }

        do {
            Logger.shared.info("Fetching configuration templates from Graph API", category: .network)

            let endpoint = "/deviceManagement/configurationPolicyTemplates"
            let response: ConfigurationPolicyTemplateResponse = try await apiClient.getModel(
                endpoint
            )

            var allTemplates: [ConfigurationTemplate] = []
            for template in response.value {
                allTemplates.append(template.toConfigurationTemplate())
            }

            // Update local cache
            templates = allTemplates
            dataStore.replaceConfigurationTemplates(allTemplates)

            Logger.shared.info("Successfully fetched \(allTemplates.count) configuration templates", category: .network)
            return allTemplates
        } catch {
            self.error = error
            Logger.shared.error("Failed to fetch configuration templates: \(error)", category: .network)
            throw error
        }
    }

    /// Fetch Settings Catalog templates
    func fetchSettingsCatalogTemplates(
        platform: DeviceManagementConfigurationPolicy.Platform? = nil
    ) async throws -> [DeviceManagementConfigurationPolicyTemplate] {
        Logger.shared.info("Fetching Settings Catalog templates", category: .network)

        var endpoint = "/deviceManagement/configurationPolicyTemplates"
        if let platform = platform {
            endpoint += "?$filter=platforms has '\(platform.rawValue)'"
        }

        let response: SettingsCatalogTemplateResponse = try await apiClient.getModel(
            endpoint
        )

        Logger.shared.info("Successfully fetched \(response.value.count) templates", category: .network)
        return response.value
    }

    /// Fetch setting definitions for a template
    func fetchSettingDefinitionsForTemplate(
        templateId: String
    ) async throws -> [DeviceManagementConfigurationSettingDefinition] {
        Logger.shared.info("Fetching setting definitions for template: \(templateId)", category: .network)

        let endpoint = "/deviceManagement/configurationPolicyTemplates/\(templateId)/settingTemplates"

        let response: SettingTemplateResponse = try await apiClient.getModel(
            endpoint
        )

        var allDefinitions: [DeviceManagementConfigurationSettingDefinition] = []
        for template in response.value {
            if let definitions = template.settingDefinitions {
                allDefinitions.append(contentsOf: definitions)
            }
        }

        Logger.shared.info("Successfully fetched \(allDefinitions.count) setting definitions", category: .network)
        return allDefinitions
    }

    /// Fetch available settings from Settings Catalog
    func fetchAvailableSettings(
        platform: DeviceManagementConfigurationPolicy.Platform? = nil,
        technology: DeviceManagementConfigurationPolicy.Technology? = nil,
        searchTerm: String? = nil
    ) async throws -> [DeviceManagementConfigurationSettingDefinition] {
        Logger.shared.info("Fetching available settings from Settings Catalog", category: .network)

        var endpoint = "/deviceManagement/configurationSettings"
        var filters: [String] = []

        if let platform = platform {
            filters.append("applicability/platform eq '\(platform.rawValue)'")
        }
        if let technology = technology {
            filters.append("applicability/technologies has '\(technology.rawValue)'")
        }
        if let searchTerm = searchTerm {
            filters.append("contains(displayName, '\(searchTerm)')")
        }

        if !filters.isEmpty {
            endpoint += "?$filter=\(filters.joined(separator: " and "))"
        }

        let response: SettingDefinitionResponse = try await apiClient.getModel(
            endpoint
        )

        Logger.shared.info("Successfully fetched \(response.value.count) setting definitions", category: .network)
        return response.value
    }

    // MARK: - Assignment Management

    /// Update assignments for a configuration profile
    func updateProfileAssignments(
        profileId: String,
        assignments: [ConfigurationAssignment],
        isSettingsCatalog: Bool = false
    ) async throws {
        Logger.shared.info("Updating assignments for profile: \(profileId)", category: .network)

        let endpoint = isSettingsCatalog ?
            "/deviceManagement/configurationPolicies/\(profileId)/assign" :
            "/deviceManagement/deviceConfigurations/\(profileId)/assign"

        let requestBody = AssignmentRequest(
            assignments: assignments.map { $0.toGraphAssignment() }
        )

        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: requestBody)

        // Update local copy
        if let index = profiles.firstIndex(where: { $0.id == profileId }) {
            profiles[index].assignments = assignments
            profiles[index].isAssigned = !assignments.isEmpty
            dataStore.updateConfigurationProfile(profiles[index])
        }

        Logger.shared.info("Successfully updated assignments for profile", category: .network)
    }

    // MARK: - Search and Filter

    /// Search profiles by name or description
    func searchProfiles(_ query: String) -> [ConfigurationProfile] {
        guard !query.isEmpty else { return profiles }

        return profiles.filter { profile in
            profile.displayName.localizedCaseInsensitiveContains(query) ||
            (profile.profileDescription?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    /// Filter profiles by platform
    func profilesForPlatform(_ platform: ConfigurationProfile.PlatformType) -> [ConfigurationProfile] {
        profiles.filter { $0.platformType == platform }
    }

    /// Filter profiles by type
    func profilesForType(_ type: ConfigurationProfile.ProfileType) -> [ConfigurationProfile] {
        profiles.filter { $0.profileType == type }
    }

    /// Filter templates by platform
    func templatesForPlatform(_ platform: String) -> [ConfigurationTemplate] {
        templates.filter { template in
            template.platformTypes.contains(platform)
        }
    }
}

// MARK: - Request/Response Models

private struct AssignmentRequest: Encodable {
    let assignments: [GraphAssignmentRequest]
}

private struct GraphAssignmentRequest: Encodable {
    let target: GraphTarget

    struct GraphTarget: Encodable {
        let odataType: String
        let groupId: String?

        enum CodingKeys: String, CodingKey {
            case odataType = "@odata.type"
            case groupId
        }
    }
}

// Response models for Settings Catalog
private struct SettingsCatalogPolicyResponse: Codable {
    let value: [SettingsCatalogPolicy]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

private struct SettingsCatalogTemplateResponse: Codable {
    let value: [DeviceManagementConfigurationPolicyTemplate]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

private struct SettingDefinitionResponse: Codable {
    let value: [DeviceManagementConfigurationSettingDefinition]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

private struct SettingTemplateResponse: Codable {
    let value: [SettingTemplate]
    let nextLink: String?

    struct SettingTemplate: Codable {
        let id: String
        let settingDefinitions: [DeviceManagementConfigurationSettingDefinition]?
    }

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

private struct SettingsCatalogPolicy: Codable {
    let id: String
    let name: String
    let description: String?
    let createdDateTime: String
    let lastModifiedDateTime: String
    let platforms: String?
    let technologies: String?
    let templateReference: TemplateRef?
    let settings: [SettingInstance]?

    struct TemplateRef: Codable {
        let templateId: String
        let templateDisplayName: String?
    }

    func toConfigurationProfile() -> ConfigurationProfile {
        let dateFormatter = ISO8601DateFormatter()

        let platformType: ConfigurationProfile.PlatformType
        if let platforms = platforms?.lowercased() {
            if platforms.contains("ios") {
                platformType = .iOS
            } else if platforms.contains("macos") {
                platformType = .macOS
            } else if platforms.contains("android") {
                platformType = .android
            } else {
                platformType = .windows10
            }
        } else {
            platformType = .windows10
        }

        let profile = ConfigurationProfile(
            id: id,
            displayName: name,
            profileDescription: description,
            platformType: platformType,
            profileType: .settingsCatalog,
            templateId: templateReference?.templateId,
            templateDisplayName: templateReference?.templateDisplayName
        )

        profile.createdDateTime = dateFormatter.date(from: createdDateTime) ?? Date()
        profile.lastModifiedDateTime = dateFormatter.date(from: lastModifiedDateTime) ?? Date()

        return profile
    }
}

// MARK: - Extensions

extension ConfigurationAssignment {
    fileprivate func toGraphAssignment() -> GraphAssignmentRequest {
        let odataType: String
        switch target.type {
        case .allDevices:
            odataType = "#microsoft.graph.allDevicesAssignmentTarget"
        case .allUsers:
            odataType = "#microsoft.graph.allUsersAssignmentTarget"
        case .exclusionGroup:
            odataType = "#microsoft.graph.exclusionGroupAssignmentTarget"
        case .group:
            odataType = "#microsoft.graph.groupAssignmentTarget"
        case .allLicensedUsers:
            odataType = "#microsoft.graph.allLicensedUsersAssignmentTarget"
        }

        return GraphAssignmentRequest(
            target: GraphAssignmentRequest.GraphTarget(
                odataType: odataType,
                groupId: target.groupId
            )
        )
    }
}

// MARK: - LocalDataStore Extensions

extension LocalDataStore {
    func fetchConfigurationProfiles() -> [ConfigurationProfile] {
        // Implementation would fetch from SwiftData
        []
    }

    func fetchConfigurationTemplates() -> [ConfigurationTemplate] {
        // Implementation would fetch from SwiftData
        []
    }

    func replaceConfigurationProfiles(_ profiles: [ConfigurationProfile]) {
        // Implementation would replace in SwiftData
    }

    func replaceConfigurationTemplates(_ templates: [ConfigurationTemplate]) {
        // Implementation would replace in SwiftData
    }

    func updateConfigurationProfile(_ profile: ConfigurationProfile) {
        // Implementation would update in SwiftData
    }
}
