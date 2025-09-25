import Foundation
import SwiftData

/// Represents a configuration policy template
@Model
final class ConfigurationTemplate: Identifiable, Codable, Sendable {
    @Attribute(.unique) var id: String
    var displayName: String
    var templateDescription: String?
    var platformTypes: [String]
    var technologies: [String]
    var templateType: String
    var settingsCount: Int
    var isDeprecated: Bool
    var templateSchemaUri: String?
    var categories: [TemplateCategory]?

    /// Template category for organizing settings
    struct TemplateCategory: Codable {
        let id: String
        let displayName: String
        let description: String?
        let childCategories: [TemplateCategory]?
        let settingsDefinitions: [String]? // IDs of settings in this category
    }

    init(
        id: String,
        displayName: String,
        templateDescription: String? = nil,
        platformTypes: [String] = [],
        technologies: [String] = [],
        templateType: String = "configurationPolicy",
        settingsCount: Int = 0,
        isDeprecated: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.templateDescription = templateDescription
        self.platformTypes = platformTypes
        self.technologies = technologies
        self.templateType = templateType
        self.settingsCount = settingsCount
        self.isDeprecated = isDeprecated
        self.templateSchemaUri = nil
        self.categories = []
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case templateDescription = "description"
        case platformTypes
        case technologies
        case templateType
        case settingsCount
        case isDeprecated
        case templateSchemaUri
        case categories
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        templateDescription = try container.decodeIfPresent(String.self, forKey: .templateDescription)
        platformTypes = try container.decodeIfPresent([String].self, forKey: .platformTypes) ?? []
        technologies = try container.decodeIfPresent([String].self, forKey: .technologies) ?? []
        templateType = try container.decodeIfPresent(String.self, forKey: .templateType) ?? "configurationPolicy"
        settingsCount = try container.decodeIfPresent(Int.self, forKey: .settingsCount) ?? 0
        isDeprecated = try container.decodeIfPresent(Bool.self, forKey: .isDeprecated) ?? false
        templateSchemaUri = try container.decodeIfPresent(String.self, forKey: .templateSchemaUri)
        categories = try container.decodeIfPresent([TemplateCategory].self, forKey: .categories)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(templateDescription, forKey: .templateDescription)
        try container.encode(platformTypes, forKey: .platformTypes)
        try container.encode(technologies, forKey: .technologies)
        try container.encode(templateType, forKey: .templateType)
        try container.encode(settingsCount, forKey: .settingsCount)
        try container.encode(isDeprecated, forKey: .isDeprecated)
        try container.encodeIfPresent(templateSchemaUri, forKey: .templateSchemaUri)
        try container.encodeIfPresent(categories, forKey: .categories)
    }
}

// MARK: - Graph API Response Models

/// Response model for configuration policy templates from Graph API
struct ConfigurationPolicyTemplateResponse: Codable {
    let value: [ConfigurationPolicyTemplate]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

/// Individual configuration policy template from Graph API
struct ConfigurationPolicyTemplate: Codable {
    let id: String
    let displayName: String
    let description: String?
    let platforms: String?
    let technologies: String?
    let templateFamily: String?
    let allowUnmanagedSettings: Bool?
    let settingTemplates: [SettingTemplate]?

    /// Setting template within a configuration template
    struct SettingTemplate: Codable {
        let id: String
        let settingInstanceTemplate: SettingInstanceTemplate?
    }

    /// Setting instance template
    struct SettingInstanceTemplate: Codable {
        let settingDefinitionId: String
        let settingInstanceTemplateId: String
        let isRequired: Bool?
    }

    /// Convert Graph API response to our model
    func toConfigurationTemplate() -> ConfigurationTemplate {
        let platformList = platforms?.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } ?? []
        let techList = technologies?.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) } ?? []

        return ConfigurationTemplate(
            id: id,
            displayName: displayName,
            templateDescription: description,
            platformTypes: platformList,
            technologies: techList,
            templateType: templateFamily ?? "configurationPolicy",
            settingsCount: settingTemplates?.count ?? 0,
            isDeprecated: false
        )
    }
}