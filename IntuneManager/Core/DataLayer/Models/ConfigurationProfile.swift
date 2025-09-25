import Foundation
import SwiftData

/// Represents a device configuration profile in Intune
@Model
final class ConfigurationProfile: Identifiable, Codable, Sendable {
    @Attribute(.unique) var id: String
    var displayName: String
    var profileDescription: String?
    var createdDateTime: Date
    var lastModifiedDateTime: Date
    var version: Int
    var platformType: PlatformType
    var profileType: ProfileType
    var templateId: String?
    var templateDisplayName: String?
    var isAssigned: Bool
    var roleScopeTagIds: [String]
    var settings: [ConfigurationSetting]?
    var assignments: [ConfigurationAssignment]?

    /// Platform types for configuration profiles
    enum PlatformType: String, Codable, CaseIterable {
        case android = "android"
        case iOS = "iOS"
        case macOS = "macOS"
        case windows10 = "windows10"
        case androidEnterprise = "androidEnterprise"
        case androidWorkProfile = "androidWorkProfile"

        var displayName: String {
            switch self {
            case .android: return "Android"
            case .iOS: return "iOS/iPadOS"
            case .macOS: return "macOS"
            case .windows10: return "Windows"
            case .androidEnterprise: return "Android Enterprise"
            case .androidWorkProfile: return "Android Work Profile"
            }
        }

        var icon: String {
            switch self {
            case .android, .androidEnterprise, .androidWorkProfile: return "android"
            case .iOS: return "iphone"
            case .macOS: return "desktopcomputer"
            case .windows10: return "pc"
            }
        }
    }

    /// Profile types (templates vs settings catalog)
    enum ProfileType: String, Codable, CaseIterable {
        case deviceConfiguration = "deviceConfiguration"
        case settingsCatalog = "settingsCatalog"
        case template = "template"
        case custom = "custom"
        case compliancePolicy = "compliancePolicy"
        case administrativeTemplate = "administrativeTemplate"

        var displayName: String {
            switch self {
            case .deviceConfiguration: return "Device Configuration"
            case .settingsCatalog: return "Settings Catalog"
            case .template: return "Template"
            case .custom: return "Custom"
            case .compliancePolicy: return "Compliance Policy"
            case .administrativeTemplate: return "Administrative Template"
            }
        }

        var icon: String {
            switch self {
            case .deviceConfiguration: return "gearshape"
            case .settingsCatalog: return "list.bullet.rectangle"
            case .template: return "doc.text"
            case .custom: return "wrench.and.screwdriver"
            case .compliancePolicy: return "checkmark.shield"
            case .administrativeTemplate: return "doc.badge.gearshape"
            }
        }
    }

    init(
        id: String,
        displayName: String,
        profileDescription: String? = nil,
        platformType: PlatformType,
        profileType: ProfileType,
        templateId: String? = nil,
        templateDisplayName: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.profileDescription = profileDescription
        self.createdDateTime = Date()
        self.lastModifiedDateTime = Date()
        self.version = 1
        self.platformType = platformType
        self.profileType = profileType
        self.templateId = templateId
        self.templateDisplayName = templateDisplayName
        self.isAssigned = false
        self.roleScopeTagIds = []
        self.settings = []
        self.assignments = []
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case profileDescription = "description"
        case createdDateTime
        case lastModifiedDateTime
        case version
        case platformType
        case profileType
        case templateId
        case templateDisplayName
        case isAssigned
        case roleScopeTagIds
        case settings
        case assignments
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        profileDescription = try container.decodeIfPresent(String.self, forKey: .profileDescription)
        createdDateTime = try container.decode(Date.self, forKey: .createdDateTime)
        lastModifiedDateTime = try container.decode(Date.self, forKey: .lastModifiedDateTime)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        platformType = try container.decode(PlatformType.self, forKey: .platformType)
        profileType = try container.decode(ProfileType.self, forKey: .profileType)
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId)
        templateDisplayName = try container.decodeIfPresent(String.self, forKey: .templateDisplayName)
        isAssigned = try container.decodeIfPresent(Bool.self, forKey: .isAssigned) ?? false
        roleScopeTagIds = try container.decodeIfPresent([String].self, forKey: .roleScopeTagIds) ?? []
        settings = try container.decodeIfPresent([ConfigurationSetting].self, forKey: .settings)
        assignments = try container.decodeIfPresent([ConfigurationAssignment].self, forKey: .assignments)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profileDescription, forKey: .profileDescription)
        try container.encode(createdDateTime, forKey: .createdDateTime)
        try container.encode(lastModifiedDateTime, forKey: .lastModifiedDateTime)
        try container.encode(version, forKey: .version)
        try container.encode(platformType, forKey: .platformType)
        try container.encode(profileType, forKey: .profileType)
        try container.encodeIfPresent(templateId, forKey: .templateId)
        try container.encodeIfPresent(templateDisplayName, forKey: .templateDisplayName)
        try container.encode(isAssigned, forKey: .isAssigned)
        try container.encode(roleScopeTagIds, forKey: .roleScopeTagIds)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(assignments, forKey: .assignments)
    }
}

// MARK: - Graph API Response Models

/// Response model for device configuration from Graph API
struct DeviceConfigurationResponse: Codable {
    let value: [DeviceConfiguration]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

/// Individual device configuration from Graph API
struct DeviceConfiguration: Codable {
    let id: String
    let displayName: String
    let description: String?
    let createdDateTime: String
    let lastModifiedDateTime: String
    let version: Int?
    let odataType: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case description
        case createdDateTime
        case lastModifiedDateTime
        case version
        case odataType = "@odata.type"
    }

    /// Convert Graph API response to our model
    func toConfigurationProfile() -> ConfigurationProfile? {
        // Determine platform and profile type from odata.type
        let (platform, profileType) = parsePlatformAndType(from: odataType)

        let dateFormatter = ISO8601DateFormatter()
        let created = dateFormatter.date(from: createdDateTime) ?? Date()
        let modified = dateFormatter.date(from: lastModifiedDateTime) ?? Date()

        return ConfigurationProfile(
            id: id,
            displayName: displayName,
            profileDescription: description,
            platformType: platform,
            profileType: profileType
        )
    }

    private func parsePlatformAndType(from odataType: String) -> (ConfigurationProfile.PlatformType, ConfigurationProfile.ProfileType) {
        // Parse the odata.type to determine platform and profile type
        let type = odataType.lowercased()

        var platform: ConfigurationProfile.PlatformType = .windows10
        var profileType: ConfigurationProfile.ProfileType = .deviceConfiguration

        if type.contains("ios") || type.contains("ipad") {
            platform = .iOS
        } else if type.contains("macos") || type.contains("mac") {
            platform = .macOS
        } else if type.contains("androidworkprofile") {
            platform = .androidWorkProfile
        } else if type.contains("androidenterprise") {
            platform = .androidEnterprise
        } else if type.contains("android") {
            platform = .android
        } else if type.contains("windows") {
            platform = .windows10
        }

        if type.contains("settingscatalog") || type.contains("configurationpolicy") {
            profileType = .settingsCatalog
        } else if type.contains("template") {
            profileType = .template
        } else if type.contains("compliance") {
            profileType = .compliancePolicy
        } else if type.contains("administrative") {
            profileType = .administrativeTemplate
        } else if type.contains("custom") {
            profileType = .custom
        }

        return (platform, profileType)
    }
}