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

// MARK: - macOS LOB/DMG/PKG App Assignment Settings
// Per Microsoft Graph API docs, all macOS LOB-based apps (DMG, PKG, LOB) use the same assignment settings type
// Detection rules, version detection, and minimum OS are properties of the APP itself during creation, not assignment
struct MacOSLobAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // macOS LOB specific settings - following validated Intune defaults:
    var uninstallOnDeviceRemoval: Bool = false // ✓ Defaults to No

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case uninstallOnDeviceRemoval
    }

    var odataType: String {
        return "#microsoft.graph.macOsLobAppAssignmentSettings"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(odataType, forKey: .odataType)

        // Only send if true (different from default false)
        if uninstallOnDeviceRemoval {  // Default is false
            try container.encode(uninstallOnDeviceRemoval, forKey: .uninstallOnDeviceRemoval)
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
        self.uninstallOnDeviceRemoval = try container.decodeIfPresent(Bool.self, forKey: .uninstallOnDeviceRemoval) ?? false
    }

    init() {
        // Keep default values from property declarations
    }
}

// MARK: - Android Managed Store App Assignment Settings
struct AndroidManagedStoreAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // Android specific settings - following Microsoft Graph API schema
    var autoUpdateMode: AutoUpdateMode = .default
    var androidManagedStoreAppTrackIds: [String]?

    enum AutoUpdateMode: String, Codable, CaseIterable {
        case `default`
        case postponed
        case priority

        var displayName: String {
            switch self {
            case .default: return "Default"
            case .postponed: return "Postponed (up to 90 days)"
            case .priority: return "High Priority"
            }
        }

        var description: String {
            switch self {
            case .default:
                return "Updates when device is connected to Wi-Fi, charging, not actively used, and app is not in foreground"
            case .postponed:
                return "Updates are postponed for a maximum of 90 days after the app becomes out of date"
            case .priority:
                return "App is updated as soon as possible. If device is online, updates within minutes"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case autoUpdateMode
        case androidManagedStoreAppTrackIds
    }

    var odataType: String {
        return "#microsoft.graph.androidManagedStoreAppAssignmentSettings"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(odataType, forKey: .odataType)

        // Auto update mode (always include as it has a default)
        try container.encode(autoUpdateMode, forKey: .autoUpdateMode)

        // Track IDs - only if specified
        if let trackIds = androidManagedStoreAppTrackIds, !trackIds.isEmpty {
            try container.encode(trackIds, forKey: .androidManagedStoreAppTrackIds)
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
        self.autoUpdateMode = try container.decodeIfPresent(AutoUpdateMode.self, forKey: .autoUpdateMode) ?? .default
        self.androidManagedStoreAppTrackIds = try container.decodeIfPresent([String].self, forKey: .androidManagedStoreAppTrackIds)
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
    var macosLobSettings: MacOSLobAppAssignmentSettings? // Used for DMG, PKG, and LOB apps
    var windowsSettings: WindowsAppAssignmentSettings?
    var androidSettings: AndroidManagedStoreAppAssignmentSettings?

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

    static func macosLob(intent: Assignment.AssignmentIntent) -> AppAssignmentSettings {
        var settings = AppAssignmentSettings(intent: intent)
        settings.macosLobSettings = MacOSLobAppAssignmentSettings()
        return settings
    }

    static func windows(intent: Assignment.AssignmentIntent) -> AppAssignmentSettings {
        var settings = AppAssignmentSettings(intent: intent)
        settings.windowsSettings = WindowsAppAssignmentSettings()
        return settings
    }

    static func android(intent: Assignment.AssignmentIntent) -> AppAssignmentSettings {
        var settings = AppAssignmentSettings(intent: intent)
        settings.androidSettings = AndroidManagedStoreAppAssignmentSettings()
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
        case .macOSDmgApp, .macOSPkgApp, .macOSLobApp:
            // All macOS LOB-based apps use the same assignment settings type
            return macosLobSettings
        case .windowsWebApp, .win32LobApp, .winGetApp:
            return windowsSettings
        case .androidStoreApp, .androidManagedStoreApp:
            return androidSettings
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
        case .macOSDmgApp, .macOSPkgApp, .macOSLobApp:
            self.settings = .macosLob(intent: intent)
        case .windowsWebApp, .win32LobApp, .winGetApp:
            self.settings = .windows(intent: intent)
        case .androidStoreApp, .androidManagedStoreApp:
            self.settings = .android(intent: intent)
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
            description: "Assign the app using device licenses instead of user licenses. Device licensing allows apps to be installed without requiring users to sign in with an Apple ID. This is ideal for shared devices or when you want to deploy apps without user interaction. Intune defaults to device licensing for better deployment flexibility.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/vpp-apps-ios#assign-a-volume-purchased-app"
        ),
        "vpnConfiguration": AssignmentSettingDescription(
            key: "vpnConfiguration",
            title: "VPN Configuration",
            description: "Automatically connect to a VPN when this app launches. Select an existing VPN profile to associate with this app. The VPN connection will establish before the app opens, ensuring secure connectivity for apps that require internal network access.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/configuration/vpn-settings-ios"
        ),
        "uninstallOnDeviceRemoval": AssignmentSettingDescription(
            key: "uninstallOnDeviceRemoval",
            title: "Uninstall on device removal",
            description: "Automatically uninstall this app when the device is removed from Intune management, retired, or wiped. This helps maintain license compliance and ensures apps are removed when devices are no longer managed by your organization.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-deploy#uninstall-apps"
        ),
        "isRemovable": AssignmentSettingDescription(
            key: "isRemovable",
            title: "Allow app removal",
            description: "Controls whether users can uninstall this app from their device. When set to 'Yes', users can remove the app through normal iOS uninstall methods. When set to 'No', the app cannot be removed by the user, ensuring critical business apps remain installed.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/app-configuration-policies-use-ios"
        ),
        "preventManagedAppBackup": AssignmentSettingDescription(
            key: "preventManagedAppBackup",
            title: "Prevent iCloud backup",
            description: "Prevents this managed app's data from being backed up to iCloud. Enable this setting to ensure sensitive corporate data within the app doesn't get synchronized to personal iCloud accounts, maintaining data sovereignty and compliance.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/app-protection-policy-settings-ios"
        ),
        "preventAutoAppUpdate": AssignmentSettingDescription(
            key: "preventAutoAppUpdate",
            title: "Prevent automatic updates",
            description: "Prevents the app from updating automatically through the App Store. When enabled, app updates must be deployed through Intune, giving IT administrators control over app versions and the ability to test updates before deployment.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-deploy#prevent-automatic-updating-of-apps"
        )
    ]

    static let macosDescriptions: [String: AssignmentSettingDescription] = [
        "useDeviceLicensing": AssignmentSettingDescription(
            key: "useDeviceLicensing",
            title: "Device Licensing",
            description: "Assign the app using device licenses instead of user licenses. Device licensing simplifies app deployment on shared Macs and doesn't require users to sign in with an Apple ID. This is the recommended approach for lab computers, kiosks, and shared workstations.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/vpp-apps-macos"
        ),
        "uninstallOnDeviceRemoval": AssignmentSettingDescription(
            key: "uninstallOnDeviceRemoval",
            title: "Uninstall on device removal",
            description: "Automatically uninstall this app when the Mac is removed from Intune management. This helps reclaim licenses and ensures corporate apps are removed when devices leave your organization's management.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-deploy#uninstall-apps"
        ),
        "preventAutoAppUpdate": AssignmentSettingDescription(
            key: "preventAutoAppUpdate",
            title: "Prevent automatic updates",
            description: "Prevents the app from updating automatically through the Mac App Store. When enabled, updates must be deployed through Intune, allowing IT to test compatibility and control the rollout of new versions.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-deploy#prevent-automatic-updating-of-apps"
        ),
        "minimumOperatingSystem": AssignmentSettingDescription(
            key: "minimumOperatingSystem",
            title: "Minimum operating system",
            description: "Specifies the minimum macOS version required to install this DMG app. The app will only install on devices running this version or later. Use semantic versioning (e.g., 14.0, 13.5, 12.7.1) to ensure compatibility.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-macos-dmg"
        ),
        "ignoreVersionDetection": AssignmentSettingDescription(
            key: "ignoreVersionDetection",
            title: "Ignore version detection",
            description: "When enabled, Intune will install the app regardless of any existing version on the device. Use this for apps that don't properly report version information or when you always want to force installation of your packaged version.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-macos-dmg#app-information"
        ),
        "detectionRules": AssignmentSettingDescription(
            key: "detectionRules",
            title: "Detection rules",
            description: "Define rules to detect if the app is already installed. You can check for file/folder existence or version information. Detection rules prevent unnecessary reinstallation and help Intune report accurate compliance status.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-macos-dmg#step-3-requirements"
        )
    ]

    static let androidDescriptions: [String: AssignmentSettingDescription] = [
        "autoUpdateMode": AssignmentSettingDescription(
            key: "autoUpdateMode",
            title: "App Update Priority",
            description: "Controls how quickly updates are applied to this Android app. Default mode balances battery life and network usage by updating during optimal conditions. Postponed mode delays updates up to 90 days for controlled rollouts. High Priority mode updates as soon as possible, ideal for security patches and critical fixes.",
            helpUrl: "https://learn.microsoft.com/en-us/graph/api/resources/intune-shared-androidmanagedstoreautoupdatemode"
        ),
        "androidManagedStoreAppTrackIds": AssignmentSettingDescription(
            key: "androidManagedStoreAppTrackIds",
            title: "App Tracks",
            description: "Select which app version tracks to enable for this assignment. Tracks allow staged rollouts and beta testing. Common tracks include Production (stable releases), Beta (pre-release testing), Alpha (early testing), and Internal (private testing). Multiple tracks can be enabled to provide different versions to different groups.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-add-android-for-work"
        )
    ]

    static let windowsDescriptions: [String: AssignmentSettingDescription] = [
        "deliveryOptimizationPriority": AssignmentSettingDescription(
            key: "deliveryOptimizationPriority",
            title: "Delivery optimization priority",
            description: "Controls the priority for downloading this app. 'Foreground' gives the app higher priority and faster download speeds, useful for critical apps. 'Not configured' uses default Windows settings for balanced performance.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management#delivery-optimization"
        ),
        "notifications": AssignmentSettingDescription(
            key: "notifications",
            title: "End user notifications",
            description: "Controls what notifications users see during app installation. 'Show all' displays progress and completion notifications. 'Show reboot only' shows only restart prompts. 'Hide all' runs installations silently without user notifications.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management#end-user-notifications"
        ),
        "restartSettings": AssignmentSettingDescription(
            key: "restartSettings",
            title: "Device restart settings",
            description: "Configure device restart behavior after app installation. Set grace periods to give users time to save work, configure countdown timers before automatic restart, and define snooze durations. These settings help balance IT requirements with user productivity.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management#device-restart-behavior"
        ),
        "gracePeriodInMinutes": AssignmentSettingDescription(
            key: "gracePeriodInMinutes",
            title: "Grace period (minutes)",
            description: "Time in minutes before a required restart is enforced after app installation. During this period, users can save their work and close applications. Default is 1440 minutes (24 hours) to minimize disruption.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management#device-restart-behavior"
        ),
        "installTimeSettings": AssignmentSettingDescription(
            key: "installTimeSettings",
            title: "Installation deadline",
            description: "Set a deadline for when the app must be installed. After the deadline, installation becomes mandatory and cannot be postponed. Use local time zones to respect working hours across different regions.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-app-management#installation-time-requirements"
        ),
        "assignmentFilter": AssignmentSettingDescription(
            key: "assignmentFilter",
            title: "Assignment filters",
            description: "Use filters to refine assignments based on device properties like OS version, manufacturer, or model. Filters help target specific device subsets within assigned groups for more precise app deployment.",
            helpUrl: "https://learn.microsoft.com/en-us/mem/intune/fundamentals/filters"
        )
    ]
}