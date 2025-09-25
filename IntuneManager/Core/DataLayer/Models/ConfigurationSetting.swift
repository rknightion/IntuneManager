import Foundation
import SwiftData

/// Represents a configuration setting within a profile
@Model
final class ConfigurationSetting: Identifiable, Codable, Sendable {
    @Attribute(.unique) var id: String
    var settingDefinitionId: String
    var displayName: String
    var settingDescription: String?
    var valueType: SettingValueType
    var value: String? // JSON encoded value
    var isRequired: Bool
    var category: String?
    var dependsOn: [String]? // IDs of other settings this depends on
    var applicability: SettingApplicability?

    /// Types of setting values
    enum SettingValueType: String, Codable, CaseIterable {
        case string = "string"
        case integer = "integer"
        case boolean = "boolean"
        case choice = "choice"
        case multiChoice = "multiChoice"
        case complex = "complex"
        case collection = "collection"

        var displayName: String {
            switch self {
            case .string: return "Text"
            case .integer: return "Number"
            case .boolean: return "Yes/No"
            case .choice: return "Choice"
            case .multiChoice: return "Multiple Choice"
            case .complex: return "Complex"
            case .collection: return "Collection"
            }
        }

        var icon: String {
            switch self {
            case .string: return "text.alignleft"
            case .integer: return "number"
            case .boolean: return "switch.2"
            case .choice: return "circle.inset.filled"
            case .multiChoice: return "checklist"
            case .complex: return "cube"
            case .collection: return "tray.2"
            }
        }
    }

    /// Applicability rules for a setting
    struct SettingApplicability: Codable {
        let platform: String?
        let minOSVersion: String?
        let maxOSVersion: String?
        let technologies: [String]?
    }

    init(
        id: String = UUID().uuidString,
        settingDefinitionId: String,
        displayName: String,
        settingDescription: String? = nil,
        valueType: SettingValueType,
        value: String? = nil,
        isRequired: Bool = false,
        category: String? = nil
    ) {
        self.id = id
        self.settingDefinitionId = settingDefinitionId
        self.displayName = displayName
        self.settingDescription = settingDescription
        self.valueType = valueType
        self.value = value
        self.isRequired = isRequired
        self.category = category
        self.dependsOn = []
        self.applicability = nil
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case settingDefinitionId
        case displayName
        case settingDescription = "description"
        case valueType
        case value
        case isRequired
        case category
        case dependsOn
        case applicability
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        settingDefinitionId = try container.decode(String.self, forKey: .settingDefinitionId)
        displayName = try container.decode(String.self, forKey: .displayName)
        settingDescription = try container.decodeIfPresent(String.self, forKey: .settingDescription)
        valueType = try container.decode(SettingValueType.self, forKey: .valueType)
        value = try container.decodeIfPresent(String.self, forKey: .value)
        isRequired = try container.decodeIfPresent(Bool.self, forKey: .isRequired) ?? false
        category = try container.decodeIfPresent(String.self, forKey: .category)
        dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn)
        applicability = try container.decodeIfPresent(SettingApplicability.self, forKey: .applicability)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(settingDefinitionId, forKey: .settingDefinitionId)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(settingDescription, forKey: .settingDescription)
        try container.encode(valueType, forKey: .valueType)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encode(isRequired, forKey: .isRequired)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(dependsOn, forKey: .dependsOn)
        try container.encodeIfPresent(applicability, forKey: .applicability)
    }
}

// MARK: - Graph API Models for Settings Catalog

/// Settings catalog setting definition from Graph API
struct SettingDefinition: Codable {
    let id: String
    let displayName: String
    let description: String?
    let categoryId: String?
    let settingUsage: String?
    let uxBehavior: String?
    let visibility: String?
    let valueDefinition: SettingValueDefinition?

    /// Value definition for a setting
    struct SettingValueDefinition: Codable {
        let odataType: String

        enum CodingKeys: String, CodingKey {
            case odataType = "@odata.type"
        }
    }

    /// Convert to our model
    func toConfigurationSetting() -> ConfigurationSetting {
        let valueType: ConfigurationSetting.SettingValueType
        if let valueDef = valueDefinition {
            switch valueDef.odataType {
            case _ where valueDef.odataType.contains("String"):
                valueType = .string
            case _ where valueDef.odataType.contains("Integer"):
                valueType = .integer
            case _ where valueDef.odataType.contains("Boolean"):
                valueType = .boolean
            case _ where valueDef.odataType.contains("Choice"):
                valueType = .choice
            case _ where valueDef.odataType.contains("Collection"):
                valueType = .collection
            default:
                valueType = .complex
            }
        } else {
            valueType = .string
        }

        return ConfigurationSetting(
            settingDefinitionId: id,
            displayName: displayName,
            settingDescription: description,
            valueType: valueType,
            isRequired: false,
            category: categoryId
        )
    }
}

/// Settings catalog setting instance from Graph API
struct SettingInstance: Codable {
    let id: String?
    let settingDefinitionId: String
    let settingInstanceTemplateReference: SettingInstanceTemplateReference?
    let value: SettingValue?

    struct SettingInstanceTemplateReference: Codable {
        let settingInstanceTemplateId: String
    }

    struct SettingValue: Codable {
        let odataType: String
        let value: String?
        let children: [SettingInstance]?

        enum CodingKeys: String, CodingKey {
            case odataType = "@odata.type"
            case value
            case children
        }
    }
}