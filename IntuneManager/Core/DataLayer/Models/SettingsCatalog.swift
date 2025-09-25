import Foundation
import SwiftData

// MARK: - Settings Catalog Models

struct DeviceManagementConfigurationPolicy: Codable, Identifiable, Sendable {
    let id: String
    var displayName: String
    var description: String?
    var platforms: [Platform]?
    var technologies: [Technology]?
    var roleScopeTagIds: [String]?
    var isAssigned: Bool?
    var templateReference: ConfigurationPolicyTemplateReference?
    var settings: [DeviceManagementConfigurationSetting]?
    var createdDateTime: Date?
    var lastModifiedDateTime: Date?
    var settingCount: Int?
    var creationSource: String?

    enum Platform: String, Codable, CaseIterable {
        case none = "none"
        case android = "android"
        case androidEnterprise = "androidEnterprise"
        case iOS = "iOS"
        case macOS = "macOS"
        case windows10 = "windows10"
        case windows10Mobile = "windows10Mobile"
        case windows10Holographic = "windows10Holographic"
        case windowsPhone81 = "windowsPhone81"
        case windows81AndLater = "windows81AndLater"
        case windows10X = "windows10X"
        case androidWorkProfile = "androidWorkProfile"
        case unknown = "unknown"
        case linux = "linux"

        var displayName: String {
            switch self {
            case .none: return "None"
            case .android: return "Android"
            case .androidEnterprise: return "Android Enterprise"
            case .iOS: return "iOS/iPadOS"
            case .macOS: return "macOS"
            case .windows10: return "Windows 10"
            case .windows10Mobile: return "Windows 10 Mobile"
            case .windows10Holographic: return "Windows Holographic"
            case .windowsPhone81: return "Windows Phone 8.1"
            case .windows81AndLater: return "Windows 8.1+"
            case .windows10X: return "Windows 10X"
            case .androidWorkProfile: return "Android Work Profile"
            case .unknown: return "Unknown"
            case .linux: return "Linux"
            }
        }
    }

    enum Technology: String, Codable, CaseIterable {
        case none = "none"
        case mdm = "mdm"
        case windowsOsRecovery = "windowsOsRecovery"
        case exchangeOnline = "exchangeOnline"
        case mam = "mam"
        case linuxMdm = "linuxMdm"
        case enrollment = "enrollment"
        case endpointPrivilegeManagement = "endpointPrivilegeManagement"
        case unknown = "unknown"
        case unknownFutureValue = "unknownFutureValue"

        var displayName: String {
            switch self {
            case .none: return "None"
            case .mdm: return "MDM"
            case .windowsOsRecovery: return "Windows OS Recovery"
            case .exchangeOnline: return "Exchange Online"
            case .mam: return "App Protection"
            case .linuxMdm: return "Linux MDM"
            case .enrollment: return "Enrollment"
            case .endpointPrivilegeManagement: return "Endpoint Privilege Management"
            case .unknown, .unknownFutureValue: return "Unknown"
            }
        }
    }
}

struct ConfigurationPolicyTemplateReference: Codable {
    let templateId: String
    var templateFamily: TemplateFamily?
    var templateDisplayName: String?
    var templateDisplayVersion: String?

    enum TemplateFamily: String, Codable {
        case none = "none"
        case endpointSecurityAntivirus = "endpointSecurityAntivirus"
        case endpointSecurityDiskEncryption = "endpointSecurityDiskEncryption"
        case endpointSecurityFirewall = "endpointSecurityFirewall"
        case endpointSecurityEndpointDetectionAndResponse = "endpointSecurityEndpointDetectionAndResponse"
        case endpointSecurityAttackSurfaceReduction = "endpointSecurityAttackSurfaceReduction"
        case endpointSecurityAccountProtection = "endpointSecurityAccountProtection"
        case endpointSecurityApplicationControl = "endpointSecurityApplicationControl"
        case endpointSecurityEndpointPrivilegeManagement = "endpointSecurityEndpointPrivilegeManagement"
        case enrollmentConfiguration = "enrollmentConfiguration"
        case appQuietTime = "appQuietTime"
        case baseline = "baseline"
        case unknownFutureValue = "unknownFutureValue"
        case deviceConfigurationScripts = "deviceConfigurationScripts"
        case deviceConfigurationPolicies = "deviceConfigurationPolicies"
        case windowsOsRecoveryPolicies = "windowsOsRecoveryPolicies"
        case companyPortal = "companyPortal"
    }
}

struct DeviceManagementConfigurationSetting: Codable, Equatable {
    let id: String?
    var settingInstance: DeviceManagementConfigurationSettingInstance

    enum CodingKeys: String, CodingKey {
        case id
        case settingInstance
    }

    static func == (lhs: DeviceManagementConfigurationSetting, rhs: DeviceManagementConfigurationSetting) -> Bool {
        lhs.id == rhs.id && lhs.settingInstance.settingDefinitionId == rhs.settingInstance.settingDefinitionId
    }
}

struct DeviceManagementConfigurationSettingInstance: Codable {
    let settingDefinitionId: String
    var settingInstanceTemplateReference: SettingInstanceTemplateReference?

    // Setting value variants - only one will be populated
    var choiceSettingValue: ChoiceSettingValue?
    var simpleSettingValue: SimpleSettingValue?
    var groupSettingCollectionValue: [GroupSettingCollectionValue]?
    var simpleSettingCollectionValue: [SimpleSettingCollectionValue]?

    private enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case settingDefinitionId
        case settingInstanceTemplateReference
        case choiceSettingValue
        case simpleSettingValue
        case groupSettingCollectionValue
        case simpleSettingCollectionValue
    }

    init(
        settingDefinitionId: String,
        settingInstanceTemplateReference: SettingInstanceTemplateReference? = nil,
        choiceSettingValue: ChoiceSettingValue? = nil,
        simpleSettingValue: SimpleSettingValue? = nil,
        groupSettingCollectionValue: [GroupSettingCollectionValue]? = nil,
        simpleSettingCollectionValue: [SimpleSettingCollectionValue]? = nil
    ) {
        self.settingDefinitionId = settingDefinitionId
        self.settingInstanceTemplateReference = settingInstanceTemplateReference
        self.choiceSettingValue = choiceSettingValue
        self.simpleSettingValue = simpleSettingValue
        self.groupSettingCollectionValue = groupSettingCollectionValue
        self.simpleSettingCollectionValue = simpleSettingCollectionValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let odataType = try container.decodeIfPresent(String.self, forKey: .odataType) ?? ""

        settingDefinitionId = try container.decode(String.self, forKey: .settingDefinitionId)
        settingInstanceTemplateReference = try container.decodeIfPresent(SettingInstanceTemplateReference.self, forKey: .settingInstanceTemplateReference)

        // Decode based on odata type
        if odataType.contains("ChoiceSetting") {
            choiceSettingValue = try container.decodeIfPresent(ChoiceSettingValue.self, forKey: .choiceSettingValue)
        } else if odataType.contains("SimpleSetting") && odataType.contains("Collection") {
            simpleSettingCollectionValue = try container.decodeIfPresent([SimpleSettingCollectionValue].self, forKey: .simpleSettingCollectionValue)
        } else if odataType.contains("SimpleSetting") {
            simpleSettingValue = try container.decodeIfPresent(SimpleSettingValue.self, forKey: .simpleSettingValue)
        } else if odataType.contains("GroupSetting") {
            groupSettingCollectionValue = try container.decodeIfPresent([GroupSettingCollectionValue].self, forKey: .groupSettingCollectionValue)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Determine odata type based on which value is set
        var odataType = "#microsoft.graph.deviceManagementConfigurationSettingInstance"
        if choiceSettingValue != nil {
            odataType = "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance"
        } else if simpleSettingCollectionValue != nil {
            odataType = "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance"
        } else if simpleSettingValue != nil {
            odataType = "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance"
        } else if groupSettingCollectionValue != nil {
            odataType = "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance"
        }

        try container.encode(odataType, forKey: .odataType)
        try container.encode(settingDefinitionId, forKey: .settingDefinitionId)
        try container.encodeIfPresent(settingInstanceTemplateReference, forKey: .settingInstanceTemplateReference)
        try container.encodeIfPresent(choiceSettingValue, forKey: .choiceSettingValue)
        try container.encodeIfPresent(simpleSettingValue, forKey: .simpleSettingValue)
        try container.encodeIfPresent(groupSettingCollectionValue, forKey: .groupSettingCollectionValue)
        try container.encodeIfPresent(simpleSettingCollectionValue, forKey: .simpleSettingCollectionValue)
    }
}

struct SettingInstanceTemplateReference: Codable {
    let settingInstanceTemplateId: String
}

struct ChoiceSettingValue: Codable {
    var value: String
    var children: [DeviceManagementConfigurationSettingInstance]?
}

struct SimpleSettingValue: Codable {
    var value: SettingValueType

    init(value: SettingValueType) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self.value = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self.value = .integer(intValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = .boolean(boolValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = .double(doubleValue)
        } else {
            self.value = .string("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .string(let val):
            try container.encode(val)
        case .integer(let val):
            try container.encode(val)
        case .boolean(let val):
            try container.encode(val)
        case .double(let val):
            try container.encode(val)
        }
    }
}

struct SimpleSettingCollectionValue: Codable {
    var value: SettingValueType

    init(value: SettingValueType) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self.value = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self.value = .integer(intValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self.value = .boolean(boolValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self.value = .double(doubleValue)
        } else {
            self.value = .string("")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case .string(let val):
            try container.encode(val)
        case .integer(let val):
            try container.encode(val)
        case .boolean(let val):
            try container.encode(val)
        case .double(let val):
            try container.encode(val)
        }
    }
}

enum SettingValueType: Codable {
    case string(String)
    case integer(Int)
    case boolean(Bool)
    case double(Double)
}

struct GroupSettingCollectionValue: Codable {
    var children: [DeviceManagementConfigurationSettingInstance]?
}

// MARK: - Settings Definitions

struct DeviceManagementConfigurationSettingDefinition: Codable, Identifiable {
    let id: String
    var displayName: String?
    var description: String?
    var helpText: String?
    var name: String?
    var baseUri: String?
    var offsetUri: String?
    var rootDefinitionId: String?
    var categoryId: String?
    var settingUsage: SettingUsage?
    var uxBehavior: UxBehavior?
    var visibility: SettingVisibility?
    var applicability: SettingApplicability?
    var referredSettingInformationList: [ReferredSettingInformation]?
    var valueDefinition: ValueDefinition?
    var options: [SettingOption]?

    enum SettingUsage: String, Codable {
        case none = "none"
        case configuration = "configuration"
        case compliance = "compliance"
        case unknownFutureValue = "unknownFutureValue"
    }

    enum UxBehavior: String, Codable {
        case `default` = "default"
        case dropdown = "dropdown"
        case smallTextBox = "smallTextBox"
        case largeTextBox = "largeTextBox"
        case toggle = "toggle"
        case multiheaderGrid = "multiheaderGrid"
        case contextPane = "contextPane"
        case unknownFutureValue = "unknownFutureValue"
    }

    enum SettingVisibility: String, Codable {
        case none = "none"
        case settingsCatalog = "settingsCatalog"
        case template = "template"
        case unknownFutureValue = "unknownFutureValue"
    }
}

struct SettingApplicability: Codable {
    var description: String?
    var platform: DeviceManagementConfigurationPolicy.Platform?
    var technologies: [DeviceManagementConfigurationPolicy.Technology]?
    var deviceMode: DeviceMode?

    enum DeviceMode: String, Codable {
        case none = "none"
        case kiosk = "kiosk"
        case unknownFutureValue = "unknownFutureValue"
    }
}

struct ReferredSettingInformation: Codable {
    let settingDefinitionId: String?
}

struct ValueDefinition: Codable {
    // Base properties for all value types
}

struct SettingOption: Codable {
    let itemId: String?
    var displayName: String?
    var description: String?
    var helpText: String?
    var name: String?
    var optionValue: OptionValue?
    var dependentOn: [DependentOn]?
    var dependedOnBy: [DependedOnBy]?
}

struct OptionValue: Codable {
    var value: String?
}

struct DependentOn: Codable {
    let dependentOn: String?
    let parentSettingId: String?
}

struct DependedOnBy: Codable {
    let dependedOnBy: String?
    let required: Bool?
}

// MARK: - Policy Templates

struct DeviceManagementConfigurationPolicyTemplate: Codable, Identifiable {
    let id: String
    var baseId: String?
    var version: Int?
    var displayName: String
    var description: String?
    var displayVersion: String?
    var lifecycleState: LifecycleState?
    var platforms: [DeviceManagementConfigurationPolicy.Platform]?
    var technologies: [DeviceManagementConfigurationPolicy.Technology]?
    var templateFamily: ConfigurationPolicyTemplateReference.TemplateFamily?
    var allowUnmanagedSettings: Bool?
    var settingTemplateCount: Int?

    enum LifecycleState: String, Codable {
        case invalid = "invalid"
        case draft = "draft"
        case active = "active"
        case superseded = "superseded"
        case deprecated = "deprecated"
        case retired = "retired"
        case unknownFutureValue = "unknownFutureValue"
    }
}

// MARK: - Request/Response Models

struct CreateConfigurationPolicyRequest: Encodable {
    var displayName: String
    var description: String?
    var platforms: [DeviceManagementConfigurationPolicy.Platform]?
    var technologies: [DeviceManagementConfigurationPolicy.Technology]?
    var templateReference: ConfigurationPolicyTemplateReference?
    var settings: [DeviceManagementConfigurationSetting]?
    var roleScopeTagIds: [String]?

    private enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case displayName
        case description
        case platforms
        case technologies
        case templateReference
        case settings
        case roleScopeTagIds
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("#microsoft.graph.deviceManagementConfigurationPolicy", forKey: .odataType)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(platforms, forKey: .platforms)
        try container.encodeIfPresent(technologies, forKey: .technologies)
        try container.encodeIfPresent(templateReference, forKey: .templateReference)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(roleScopeTagIds, forKey: .roleScopeTagIds)
    }
}