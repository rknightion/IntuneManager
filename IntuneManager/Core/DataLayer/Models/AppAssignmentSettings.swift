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

    // iOS VPP specific settings
    var useDeviceLicensing: Bool = false
    var vpnConfigurationId: String?
    var uninstallOnDeviceRemoval: Bool = false
    var isRemovable: Bool = true
    var preventManagedAppBackup: Bool = false
    var preventAutoAppUpdate: Bool = false

    // Additional iOS settings from screenshots
    var installAsManaged: Bool = false

    enum CodingKeys: String, CodingKey {
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case useDeviceLicensing
        case vpnConfigurationId
        case uninstallOnDeviceRemoval
        case isRemovable
        case preventManagedAppBackup
        case preventAutoAppUpdate
        case installAsManaged
    }

    var odataType: String {
        return "#microsoft.graph.iosVppAppAssignmentSettings"
    }
}

// MARK: - iOS LOB App Assignment Settings
struct IOSLobAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // iOS LOB specific settings
    var vpnConfigurationId: String?
    var uninstallOnDeviceRemoval: Bool = false
    var isRemovable: Bool = true
    var preventManagedAppBackup: Bool = false

    enum CodingKeys: String, CodingKey {
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
}

// MARK: - macOS VPP App Assignment Settings
struct MacOSVppAppAssignmentSettings: AppAssignmentSettingsProtocol {
    var assignmentFilterId: String?
    var assignmentFilterMode: AssignmentFilterMode?

    // macOS VPP specific settings
    var useDeviceLicensing: Bool = false
    var uninstallOnDeviceRemoval: Bool = false
    var preventAutoAppUpdate: Bool = false

    enum CodingKeys: String, CodingKey {
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case useDeviceLicensing
        case uninstallOnDeviceRemoval
        case preventAutoAppUpdate
    }

    var odataType: String {
        return "#microsoft.graph.macOsVppAppAssignmentSettings"
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
        case assignmentFilterId = "deviceAndAppManagementAssignmentFilterId"
        case assignmentFilterMode = "deviceAndAppManagementAssignmentFilterType"
        case minimumOperatingSystem
        case ignoreVersionDetection
        case detectionRules
    }

    var odataType: String {
        return "#microsoft.graph.macOsDmgAppAssignmentSettings"
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
    var settings: AppAssignmentSettings

    init(groupId: String, groupName: String, appType: Application.AppType, intent: Assignment.AssignmentIntent) {
        self.id = UUID()
        self.groupId = groupId
        self.groupName = groupName

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