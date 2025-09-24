import Foundation

// MARK: - Base Assignment Settings Protocol
protocol AppAssignmentSettingsProtocol: Codable {
    var assignmentFilterId: String? { get set }
    var assignmentFilterMode: AssignmentFilterMode? { get set }
}

enum AssignmentFilterMode: String, Codable, CaseIterable {
    case include
    case exclude

    var displayName: String {
        switch self {
        case .include: return "Included"
        case .exclude: return "Excluded"
        }
    }
}

// MARK: - iOS VPP App Assignment Settings
struct IOSVppAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // iOS VPP specific settings - ONLY valid fields per Microsoft Graph API
    // Defaults manually validated against Intune portal (confirmed 2025-09-24):
    var useDeviceLicensing: Bool = true       // ✓ Defaults to Device Licensing
    var vpnConfigurationId: String?
    var uninstallOnDeviceRemoval: Bool = false // ✓ Defaults to No (app stays on device removal)
    var isRemovable: Bool = true               // ✓ Defaults to Yes (install as removable)
    var preventManagedAppBackup: Bool = false  // ✓ Defaults to No (allow iCloud backup)
    var preventAutoAppUpdate: Bool = false     // ✓ Defaults to No (allow automatic updates)
    // Note: installAsManaged is NOT valid for VPP apps - only for iOS Store apps

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case useDeviceLicensing
        case vpnConfigurationId
        case uninstallOnDeviceRemoval
        case isRemovable
        case preventManagedAppBackup
        case preventAutoAppUpdate
    }

    var odataType: String {
        return "#microsoft.graph.iosVppAppAssignmentSettings"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(odataType, forKey: .odataType)

        // Always include useDeviceLicensing for VPP apps
        try container.encode(useDeviceLicensing, forKey: .useDeviceLicensing)

        // Optional fields - only encode if they differ from defaults
        // Per Microsoft docs: null values are treated as false for boolean fields

        // VPN config - only if specified
        if let vpnId = vpnConfigurationId {
            try container.encode(vpnId, forKey: .vpnConfigurationId)
        }

        // Only send these if true (different from default false)
        if uninstallOnDeviceRemoval {  // Default is false
            try container.encode(uninstallOnDeviceRemoval, forKey: .uninstallOnDeviceRemoval)
        }
        if preventManagedAppBackup {  // Default is null/false
            try container.encode(preventManagedAppBackup, forKey: .preventManagedAppBackup)
        }
        if preventAutoAppUpdate {  // Default is null/false
            try container.encode(preventAutoAppUpdate, forKey: .preventAutoAppUpdate)
        }

        // Only send isRemovable if false (different from default true)
        if !isRemovable {  // Default is true
            try container.encode(isRemovable, forKey: .isRemovable)
        }

        // Assignment filters only if set
        if let filterId = assignmentFilterId {
            try container.encode(filterId, forKey: .assignmentFilterId)
            if let filterMode = assignmentFilterMode {
                try container.encode(filterMode.rawValue, forKey: .assignmentFilterMode)
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Skip @odata.type during decode
        self.assignmentFilterId = try container.decodeIfPresent(String.self, forKey: .assignmentFilterId)
        self.assignmentFilterMode = try container.decodeIfPresent(AssignmentFilterMode.self, forKey: .assignmentFilterMode)
        self.useDeviceLicensing = try container.decodeIfPresent(Bool.self, forKey: .useDeviceLicensing) ?? true
        self.vpnConfigurationId = try container.decodeIfPresent(String.self, forKey: .vpnConfigurationId)
        self.uninstallOnDeviceRemoval = try container.decodeIfPresent(Bool.self, forKey: .uninstallOnDeviceRemoval) ?? false
        self.isRemovable = try container.decodeIfPresent(Bool.self, forKey: .isRemovable) ?? true
        self.preventManagedAppBackup = try container.decodeIfPresent(Bool.self, forKey: .preventManagedAppBackup) ?? false
        self.preventAutoAppUpdate = try container.decodeIfPresent(Bool.self, forKey: .preventAutoAppUpdate) ?? false
        // installAsManaged is not valid for VPP apps
    }

    init() {
        // Keep default values from property declarations
    }
}

// MARK: - iOS LOB App Assignment Settings
struct IOSLobAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // iOS LOB specific settings - following validated Intune defaults:
    var vpnConfigurationId: String?
    var uninstallOnDeviceRemoval: Bool = false // ✓ Defaults to No
    var isRemovable: Bool = true               // ✓ Defaults to Yes (install as removable)
    var preventManagedAppBackup: Bool = false  // ✓ Defaults to No (allow iCloud backup)

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case vpnConfigurationId
        case uninstallOnDeviceRemoval
        case isRemovable
        case preventManagedAppBackup
    }

    var odataType: String {
        return "#microsoft.graph.iosLobAppAssignmentSettings"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(odataType, forKey: .odataType)

        // VPN config - only if specified
        if let vpnId = vpnConfigurationId {
            try container.encode(vpnId, forKey: .vpnConfigurationId)
        }

        // Only send if true (different from default false)
        if uninstallOnDeviceRemoval {  // Default is false
            try container.encode(uninstallOnDeviceRemoval, forKey: .uninstallOnDeviceRemoval)
        }
        if preventManagedAppBackup {  // Default is null/false
            try container.encode(preventManagedAppBackup, forKey: .preventManagedAppBackup)
        }

        // Only send isRemovable if false (different from default true)
        if !isRemovable {  // Default is true
            try container.encode(isRemovable, forKey: .isRemovable)
        }

        // Assignment filters only if set
        if let filterId = assignmentFilterId {
            try container.encode(filterId, forKey: .assignmentFilterId)
            if let filterMode = assignmentFilterMode {
                try container.encode(filterMode.rawValue, forKey: .assignmentFilterMode)
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Skip @odata.type during decode
        self.assignmentFilterId = try container.decodeIfPresent(String.self, forKey: .assignmentFilterId)
        self.assignmentFilterMode = try container.decodeIfPresent(AssignmentFilterMode.self, forKey: .assignmentFilterMode)
        self.vpnConfigurationId = try container.decodeIfPresent(String.self, forKey: .vpnConfigurationId)
        self.uninstallOnDeviceRemoval = try container.decodeIfPresent(Bool.self, forKey: .uninstallOnDeviceRemoval) ?? false
        self.isRemovable = try container.decodeIfPresent(Bool.self, forKey: .isRemovable) ?? true
        self.preventManagedAppBackup = try container.decodeIfPresent(Bool.self, forKey: .preventManagedAppBackup) ?? false
    }

    init() {
        // Keep default values from property declarations
    }
}

// MARK: - macOS VPP App Assignment Settings
struct MacOSVppAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // macOS VPP specific settings - following validated Intune defaults:
    var useDeviceLicensing: Bool = true       // ✓ Defaults to Device Licensing
    var uninstallOnDeviceRemoval: Bool = false // ✓ Defaults to No
    var preventAutoAppUpdate: Bool = false     // ✓ Defaults to No (allow automatic updates)

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case useDeviceLicensing
        case uninstallOnDeviceRemoval
        case preventAutoAppUpdate
    }

    var odataType: String {
        return "#microsoft.graph.macOsVppAppAssignmentSettings"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(odataType, forKey: .odataType)

        // Always include useDeviceLicensing for VPP apps
        try container.encode(useDeviceLicensing, forKey: .useDeviceLicensing)

        // Only send if true (different from default false)
        if uninstallOnDeviceRemoval {  // Default is false
            try container.encode(uninstallOnDeviceRemoval, forKey: .uninstallOnDeviceRemoval)
        }
        if preventAutoAppUpdate {  // Default is null/false
            try container.encode(preventAutoAppUpdate, forKey: .preventAutoAppUpdate)
        }

        // Assignment filters only if set
        if let filterId = assignmentFilterId {
            try container.encode(filterId, forKey: .assignmentFilterId)
            if let filterMode = assignmentFilterMode {
                try container.encode(filterMode.rawValue, forKey: .assignmentFilterMode)
            }
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Skip @odata.type during decode
        self.assignmentFilterId = try container.decodeIfPresent(String.self, forKey: .assignmentFilterId)
        self.assignmentFilterMode = try container.decodeIfPresent(AssignmentFilterMode.self, forKey: .assignmentFilterMode)
        self.useDeviceLicensing = try container.decodeIfPresent(Bool.self, forKey: .useDeviceLicensing) ?? true
        self.uninstallOnDeviceRemoval = try container.decodeIfPresent(Bool.self, forKey: .uninstallOnDeviceRemoval) ?? false
        self.preventAutoAppUpdate = try container.decodeIfPresent(Bool.self, forKey: .preventAutoAppUpdate) ?? false
    }

    init() {
        // Keep default values from property declarations
    }
}

// MARK: - macOS DMG App Assignment Settings
struct MacOSDmgAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // macOS DMG specific settings
    var minimumOperatingSystem: String? // e.g., "10.15"
    var ignoreVersionDetection: Bool = false

    // Detection rules
    var detectionRules: [DetectionRule]?

    struct DetectionRule: Codable {
        var ruleType: DetectionRuleType
        var check32BitOn64System: Bool = false
        var detectionValue: String?
        var fileOrFolderPath: String?

        enum DetectionRuleType: String, Codable {
            case file = "fileExistence"
            case folder = "folderExistence"
            case version = "fileVersion"
        }
    }

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case minimumOperatingSystem
        case ignoreVersionDetection
        case detectionRules
    }

    var odataType: String {
        return "#microsoft.graph.macOsDmgAppAssignmentSettings"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(odataType, forKey: .odataType)
        // Only encode assignment filter fields if they have values
        if let filterId = assignmentFilterId {
            try container.encode(filterId, forKey: .assignmentFilterId)
            if let filterMode = assignmentFilterMode {
                try container.encode(filterMode.rawValue, forKey: .assignmentFilterMode)
            }
        }
        if let minOS = minimumOperatingSystem {
            try container.encode(minOS, forKey: .minimumOperatingSystem)
        }
        try container.encode(ignoreVersionDetection, forKey: .ignoreVersionDetection)
        if let rules = detectionRules {
            try container.encode(rules, forKey: .detectionRules)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Skip @odata.type during decode
        self.assignmentFilterId = try container.decodeIfPresent(String.self, forKey: .assignmentFilterId)
        self.assignmentFilterMode = try container.decodeIfPresent(AssignmentFilterMode.self, forKey: .assignmentFilterMode)
        self.minimumOperatingSystem = try container.decodeIfPresent(String.self, forKey: .minimumOperatingSystem)
        self.ignoreVersionDetection = try container.decodeIfPresent(Bool.self, forKey: .ignoreVersionDetection) ?? false
        self.detectionRules = try container.decodeIfPresent([DetectionRule].self, forKey: .detectionRules)
    }

    init() {
        // Keep default values from property declarations
    }
}

// MARK: - Windows App Assignment Settings
struct WindowsAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // Windows specific settings
    var deliveryOptimizationPriority: DeliveryOptimizationPriority = .notConfigured
    var notifications: NotificationSetting = .showAll
    var restartSettings: RestartSettings?
    var installTimeSettings: InstallTimeSettings?

    enum DeliveryOptimizationPriority: String, Codable, CaseIterable {
        case notConfigured
        case foreground

        var displayName: String {
            switch self {
            case .notConfigured: return "Not Configured"
            case .foreground: return "Foreground"
            }
        }
    }

    enum NotificationSetting: String, Codable, CaseIterable {
        case showAll
        case showReboot
        case hideAll

        var displayName: String {
            switch self {
            case .showAll: return "Show all notifications"
            case .showReboot: return "Show reboot notification only"
            case .hideAll: return "Hide all notifications"
            }
        }
    }

    struct RestartSettings: Codable {
        var gracePeriodInMinutes: Int = 1440 // 24 hours default
        var countdownDisplayBeforeRestartInMinutes: Int = 15
        var restartNotificationSnoozeDurationInMinutes: Int = 60
    }

    struct InstallTimeSettings: Codable {
        var useLocalTime: Bool = true
        var deadlineDateTime: Date?
    }

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case deliveryOptimizationPriority
        case notifications
        case restartSettings
        case installTimeSettings
    }

    var odataType: String {
        return "#microsoft.graph.win32LobAppAssignmentSettings"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(odataType, forKey: .odataType)
        // Only encode assignment filter fields if they have values
        if let filterId = assignmentFilterId {
            try container.encode(filterId, forKey: .assignmentFilterId)
            if let filterMode = assignmentFilterMode {
                try container.encode(filterMode.rawValue, forKey: .assignmentFilterMode)
            }
        }
        try container.encode(deliveryOptimizationPriority, forKey: .deliveryOptimizationPriority)
        try container.encode(notifications, forKey: .notifications)
        if let restart = restartSettings {
            try container.encode(restart, forKey: .restartSettings)
        }
        if let installTime = installTimeSettings {
            try container.encode(installTime, forKey: .installTimeSettings)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Skip @odata.type during decode
        self.assignmentFilterId = try container.decodeIfPresent(String.self, forKey: .assignmentFilterId)
        self.assignmentFilterMode = try container.decodeIfPresent(AssignmentFilterMode.self, forKey: .assignmentFilterMode)
        self.deliveryOptimizationPriority = try container.decodeIfPresent(DeliveryOptimizationPriority.self, forKey: .deliveryOptimizationPriority) ?? .notConfigured
        self.notifications = try container.decodeIfPresent(NotificationSetting.self, forKey: .notifications) ?? .showAll
        self.restartSettings = try container.decodeIfPresent(RestartSettings.self, forKey: .restartSettings)
        self.installTimeSettings = try container.decodeIfPresent(InstallTimeSettings.self, forKey: .installTimeSettings)
    }

    init() {
        // Keep default values from property declarations
    }
}

// MARK: - Unified Assignment Settings Container
struct AppAssignmentSettings: Codable {
    var intent: Assignment.AssignmentIntent
    var iosVppSettings: IOSVppAppAssignmentSettings?
    var iosLobSettings: IOSLobAppAssignmentSettings?
    var macosVppSettings: MacOSVppAppAssignmentSettings?
    var macosDmgSettings: MacOSDmgAppAssignmentSettings?
    var windowsSettings: WindowsAppAssignmentSettings?

    // Convenience initializers for each app type
    static func iosVpp(intent: Assignment.AssignmentIntent) -> AppAssignmentSettings {
        var settings = AppAssignmentSettings(intent: intent)
        settings.iosVppSettings = IOSVppAppAssignmentSettings()
        return settings
    }

    static func iosLob(intent: Assignment.AssignmentIntent) -> AppAssignmentSettings {
        var settings = AppAssignmentSettings(intent: intent)
        settings.iosLobSettings = IOSLobAppAssignmentSettings()
        return settings
    }

    static func macosVpp(intent: Assignment.AssignmentIntent) -> AppAssignmentSettings {
        var settings = AppAssignmentSettings(intent: intent)
        settings.macosVppSettings = MacOSVppAppAssignmentSettings()
        return settings
    }

    static func macosDmg(intent: Assignment.AssignmentIntent) -> AppAssignmentSettings {
        var settings = AppAssignmentSettings(intent: intent)
        settings.macosDmgSettings = MacOSDmgAppAssignmentSettings()
        return settings
    }

    static func windows(intent: Assignment.AssignmentIntent) -> AppAssignmentSettings {
        var settings = AppAssignmentSettings(intent: intent)
        settings.windowsSettings = WindowsAppAssignmentSettings()
        return settings
    }

    // Get the appropriate settings for the Graph API based on app type
    func getGraphSettings(for appType: Application.AppType) -> Any? {
        switch appType {
        case .iosVppApp:
            return iosVppSettings
        case .iosLobApp:
            return iosLobSettings
        case .macOSVppApp:
            return macosVppSettings
        case .macOSDmgApp:
            return macosDmgSettings
        case .windowsWebApp, .win32LobApp, .winGetApp:
            return windowsSettings
        default:
            return nil
        }
    }
}

// MARK: - Per-Group Assignment Settings
struct GroupAssignmentSettings: Identifiable, Codable {
    let id: UUID
    var groupId: String
    var groupName: String
    var assignmentMode: AssignmentMode = .include  // Include or exclude this group
    var settings: AppAssignmentSettings

    enum AssignmentMode: String, Codable, CaseIterable {
        case include = "include"
        case exclude = "exclude"

        var displayName: String {
            switch self {
            case .include:
                return "Include"
            case .exclude:
                return "Exclude"
            }
        }

        var icon: String {
            switch self {
            case .include:
                return "plus.circle"
            case .exclude:
                return "minus.circle"
            }
        }
    }

    init(groupId: String, groupName: String, appType: Application.AppType, intent: Assignment.AssignmentIntent) {
        self.id = UUID()
        self.groupId = groupId
        self.groupName = groupName
        self.assignmentMode = .include  // Default to include

        // Initialize with default settings based on app type
        switch appType {
        case .iosVppApp:
            self.settings = .iosVpp(intent: intent)
        case .iosLobApp:
            self.settings = .iosLob(intent: intent)
        case .macOSVppApp:
            self.settings = .macosVpp(intent: intent)
        case .macOSDmgApp:
            self.settings = .macosDmg(intent: intent)
        case .windowsWebApp, .win32LobApp, .winGetApp:
            self.settings = .windows(intent: intent)
        default:
            self.settings = AppAssignmentSettings(intent: intent)
        }
    }
}

// MARK: - Assignment Settings Descriptions
struct AssignmentSettingDescription {
    let key: String
    let title: String
    let description: String
    let helpUrl: String?

    static let iosVppDescriptions: [String: AssignmentSettingDescription] = [
        "useDeviceLicensing": AssignmentSettingDescription(
            key: "useDeviceLicensing",
            title: "Device Licensing",
            description: "Assign the app using device licenses instead of user licenses. Device licensing doesn't require users to sign in with an Apple ID.",
            helpUrl: "https://docs.microsoft.com/en-us/mem/intune/apps/vpp-apps-ios#assign-a-volume-purchased-app"
        ),
        "vpnConfiguration": AssignmentSettingDescription(
            key: "vpnConfiguration",
            title: "VPN",
            description: "Automatically connect to VPN when this app launches. Select a VPN profile to use.",
            helpUrl: "https://docs.microsoft.com/en-us/mem/intune/configuration/vpn-settings-ios"
        ),
        "uninstallOnDeviceRemoval": AssignmentSettingDescription(
            key: "uninstallOnDeviceRemoval",
            title: "Uninstall on device removal",
            description: "Automatically uninstall this app when the device is removed from Intune management.",
            helpUrl: "https://docs.microsoft.com/en-us/mem/intune/apps/apps-deploy#uninstall-apps"
        ),
        "isRemovable": AssignmentSettingDescription(
            key: "isRemovable",
            title: "Install as removable",
            description: "Allow users to uninstall this app from their device. When set to No, the app cannot be uninstalled by the user.",
            helpUrl: "https://docs.microsoft.com/en-us/mem/intune/apps/app-configuration-policies-use-ios"
        ),
        "preventManagedAppBackup": AssignmentSettingDescription(
            key: "preventManagedAppBackup",
            title: "Prevent iCloud app backup",
            description: "Prevent this app's data from being backed up to iCloud.",
            helpUrl: "https://docs.microsoft.com/en-us/mem/intune/apps/app-protection-policy-settings-ios"
        ),
        "preventAutoAppUpdate": AssignmentSettingDescription(
            key: "preventAutoAppUpdate",
            title: "Prevent automatic app updates",
            description: "Prevent the app from updating automatically. Updates must be deployed through Intune.",
            helpUrl: "https://docs.microsoft.com/en-us/mem/intune/apps/apps-deploy#prevent-automatic-updating-of-apps"
        )
    ]

    static let macosDescriptions: [String: AssignmentSettingDescription] = [
        "minimumOperatingSystem": AssignmentSettingDescription(
            key: "minimumOperatingSystem",
            title: "Minimum operating system",
            description: "The minimum macOS version required to install this app.",
            helpUrl: "https://docs.microsoft.com/en-us/mem/intune/apps/apps-macos-dmg"
        ),
        "detectionRules": AssignmentSettingDescription(
            key: "detectionRules",
            title: "Detection rules",
            description: "Rules to detect if the app is already installed on the device.",
            helpUrl: "https://docs.microsoft.com/en-us/mem/intune/apps/apps-macos-dmg#step-3-requirements"
        )
    ]
}