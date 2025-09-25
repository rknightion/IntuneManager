import Foundation

// MARK: - Android Work Profile General Device Configuration

struct AndroidWorkProfileGeneralDeviceConfiguration: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    // Password Settings - Device Level
    var passwordBlockFaceUnlock: Bool = false
    var passwordBlockFingerprintUnlock: Bool = false
    var passwordBlockIrisUnlock: Bool = false
    var passwordBlockTrustAgents: Bool = false
    var passwordExpirationDays: Int?
    var passwordMinimumLength: Int?
    var passwordMinutesOfInactivityBeforeScreenTimeout: Int?
    var passwordPreviousPasswordBlockCount: Int?
    var passwordSignInFailureCountBeforeFactoryReset: Int?
    var passwordRequiredType: AndroidPasswordType = .deviceDefault
    var requiredPasswordComplexity: PasswordComplexity = .none

    // Work Profile Settings
    var workProfileAllowAppInstallsFromUnknownSources: Bool = false
    var workProfileDataSharingType: DataSharingType = .deviceDefault
    var workProfileBlockNotificationsWhileDeviceLocked: Bool = false
    var workProfileBlockAddingAccounts: Bool = true
    var workProfileBluetoothEnableContactSharing: Bool = false
    var workProfileBlockScreenCapture: Bool = false
    var workProfileBlockCrossProfileCallerId: Bool = false
    var workProfileBlockCamera: Bool = false
    var workProfileBlockCrossProfileContactsSearch: Bool = false
    var workProfileBlockCrossProfileCopyPaste: Bool = false
    var workProfileDefaultAppPermissionPolicy: AppPermissionPolicy = .prompt
    var workProfileAllowWidgets: Bool = true
    var workProfileBlockPersonalAppInstallsFromUnknownSources: Bool = false
    var workProfileAccountUse: AccountUse = .allowAllExceptGoogleAccounts
    var allowedGoogleAccountDomains: [String] = []
    var blockUnifiedPasswordForWorkProfile: Bool = false

    // Work Profile Password
    var workProfilePasswordBlockFaceUnlock: Bool = false
    var workProfilePasswordBlockFingerprintUnlock: Bool = false
    var workProfilePasswordBlockIrisUnlock: Bool = false
    var workProfilePasswordBlockTrustAgents: Bool = false
    var workProfilePasswordExpirationDays: Int?
    var workProfilePasswordMinimumLength: Int?
    var workProfilePasswordMinNumericCharacters: Int?
    var workProfilePasswordMinNonLetterCharacters: Int?
    var workProfilePasswordMinLetterCharacters: Int?
    var workProfilePasswordMinLowerCaseCharacters: Int?
    var workProfilePasswordMinUpperCaseCharacters: Int?
    var workProfilePasswordMinSymbolCharacters: Int?
    var workProfilePasswordMinutesOfInactivityBeforeScreenTimeout: Int?
    var workProfilePasswordPreviousPasswordBlockCount: Int?
    var workProfilePasswordSignInFailureCountBeforeFactoryReset: Int?
    var workProfilePasswordRequiredType: AndroidPasswordType = .deviceDefault
    var workProfileRequiredPasswordComplexity: PasswordComplexity = .none
    var workProfileRequirePassword: Bool = false

    // Security
    var securityRequireVerifyApps: Bool = true

    // VPN
    var vpnAlwaysOnPackageIdentifier: String?
    var vpnEnableAlwaysOnLockdownMode: Bool = false

    enum AndroidPasswordType: String, Codable {
        case deviceDefault = "deviceDefault"
        case required = "required"
        case numeric = "numeric"
        case numericComplex = "numericComplex"
        case alphabetic = "alphabetic"
        case alphanumeric = "alphanumeric"
        case alphanumericWithSymbols = "alphanumericWithSymbols"
        case lowSecurityBiometric = "lowSecurityBiometric"
        case customPassword = "customPassword"
    }

    enum PasswordComplexity: String, Codable {
        case none = "none"
        case low = "low"
        case medium = "medium"
        case high = "high"
    }

    enum DataSharingType: String, Codable {
        case deviceDefault = "deviceDefault"
        case preventAny = "preventAny"
        case allowPersonalToWork = "allowPersonalToWork"
        case noRestrictions = "noRestrictions"
    }

    enum AppPermissionPolicy: String, Codable {
        case deviceDefault = "deviceDefault"
        case prompt = "prompt"
        case autoGrant = "autoGrant"
        case autoDeny = "autoDeny"
    }

    enum AccountUse: String, Codable {
        case blockAll = "blockAll"
        case allowAllExceptGoogleAccounts = "allowAllExceptGoogleAccounts"
        case allowAll = "allowAll"
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case passwordBlockFaceUnlock, passwordBlockFingerprintUnlock, passwordBlockIrisUnlock
        case passwordBlockTrustAgents, passwordExpirationDays, passwordMinimumLength
        case passwordMinutesOfInactivityBeforeScreenTimeout, passwordPreviousPasswordBlockCount
        case passwordSignInFailureCountBeforeFactoryReset, passwordRequiredType, requiredPasswordComplexity
        case workProfileAllowAppInstallsFromUnknownSources, workProfileDataSharingType
        case workProfileBlockNotificationsWhileDeviceLocked, workProfileBlockAddingAccounts
        case workProfileBluetoothEnableContactSharing, workProfileBlockScreenCapture
        case workProfileBlockCrossProfileCallerId, workProfileBlockCamera
        case workProfileBlockCrossProfileContactsSearch, workProfileBlockCrossProfileCopyPaste
        case workProfileDefaultAppPermissionPolicy, workProfileAllowWidgets
        case workProfileBlockPersonalAppInstallsFromUnknownSources, workProfileAccountUse
        case allowedGoogleAccountDomains, blockUnifiedPasswordForWorkProfile
        case workProfilePasswordBlockFaceUnlock, workProfilePasswordBlockFingerprintUnlock
        case workProfilePasswordBlockIrisUnlock, workProfilePasswordBlockTrustAgents
        case workProfilePasswordExpirationDays, workProfilePasswordMinimumLength
        case workProfilePasswordMinNumericCharacters, workProfilePasswordMinNonLetterCharacters
        case workProfilePasswordMinLetterCharacters, workProfilePasswordMinLowerCaseCharacters
        case workProfilePasswordMinUpperCaseCharacters, workProfilePasswordMinSymbolCharacters
        case workProfilePasswordMinutesOfInactivityBeforeScreenTimeout
        case workProfilePasswordPreviousPasswordBlockCount
        case workProfilePasswordSignInFailureCountBeforeFactoryReset
        case workProfilePasswordRequiredType, workProfileRequiredPasswordComplexity
        case workProfileRequirePassword
        case securityRequireVerifyApps
        case vpnAlwaysOnPackageIdentifier, vpnEnableAlwaysOnLockdownMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.profileDescription = try container.decodeIfPresent(String.self, forKey: .profileDescription)
        // Decode all properties with defaults...
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profileDescription, forKey: .profileDescription)
        // Encode all properties...
    }
}

// MARK: - Android Device Owner General Device Configuration

struct AndroidDeviceOwnerGeneralDeviceConfiguration: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    // Enrollment Profile
    var enrollmentProfile: EnrollmentProfileType = .notConfigured

    // Accounts
    var accountsBlockModification: Bool = false
    var accountsBlockAdd: Bool = false
    var accountsBlockRemove: Bool = false

    // Applications
    var appsAllowInstallFromUnknownSources: Bool = false
    var appsAutoUpdatePolicy: AppAutoUpdatePolicy = .userChoice
    var appsDefaultPermissionPolicy: AppPermissionPolicy = .deviceDefault
    var appsRecommendSkippingFirstUseHints: Bool = false
    var appsAllowedList: [AppListItem] = []
    var appsBlockedList: [AppListItem] = []
    var appsHideList: [AppListItem] = []
    var appsInstallAllowList: [AppListItem] = []
    var appsUninstallBlockList: [AppListItem] = []

    // Bluetooth
    var bluetoothBlockConfiguration: Bool = false
    var bluetoothBlockContactSharing: Bool = false

    // Camera
    var cameraBlocked: Bool = false

    // Cellular
    var cellularBlockDataRoaming: Bool = false
    var cellularBlockVoiceRoaming: Bool = false
    var cellularBlockWiFiTethering: Bool = false

    // Certificate Credentials
    var certificateCredentialConfigurationDisabled: Bool = false

    // Cross Profile
    var crossProfilePoliciesAllowCopyPaste: Bool = true
    var crossProfilePoliciesAllowDataSharing: DataSharingLevel = .crossProfileDataSharingUnspecified
    var crossProfilePoliciesShowWorkContactsInPersonalProfile: Bool = false

    // Data Protection
    var dataRoamingBlocked: Bool = false
    var dateTimeConfigurationBlocked: Bool = false

    // Device Features
    var factoryResetBlocked: Bool = false
    var factoryResetDeviceAdministratorEmails: [String] = []
    var globalProxy: GlobalProxySettings?
    var googleAccountsBlocked: Bool = false
    var googlePlayStoreBlocked: Bool = false
    var kioskModeApps: [AppListItem] = []
    var kioskModeWallpaperUrl: String?
    var kioskModeExitCode: String?
    var kioskModeVirtualHomeButtonEnabled: Bool = false
    var kioskModeVirtualHomeButtonType: VirtualHomeButtonType = .notConfigured
    var kioskModeBluetoothConfigurationEnabled: Bool = false
    var kioskModeDebugMenuEasyAccessEnabled: Bool = false
    var kioskModeShowAppNotificationBadge: Bool = false
    var kioskModeScreenOrientation: ScreenOrientation = .notConfigured

    // Location
    var locationModeBlocked: Bool = false
    var microsoftLauncherConfigurationEnabled: Bool = false
    var microsoftLauncherCustomWallpaperEnabled: Bool = false
    var microsoftLauncherCustomWallpaperImageUrl: String?
    var microsoftLauncherCustomWallpaperAllowUserModification: Bool = false
    var microsoftLauncherFeedEnabled: Bool = false
    var microsoftLauncherFeedAllowUserModification: Bool = false
    var microsoftLauncherDockPresenceConfiguration: DockPresenceConfiguration = .notConfigured
    var microsoftLauncherDockPresenceAllowUserModification: Bool = false
    var microsoftLauncherSearchBarPlacementConfiguration: SearchBarPlacement = .notConfigured

    // Network
    var networkEscapeHatchAllowed: Bool = false
    var nfcBlockOutgoingBeam: Bool = false

    // Password Settings
    var passwordBlockKeyguard: Bool = false
    var passwordBlockKeyguardFeatures: [KeyguardFeature] = []
    var passwordExpirationDays: Int?
    var passwordMinimumLength: Int?
    var passwordMinimumLetterCharacters: Int?
    var passwordMinimumLowerCaseCharacters: Int?
    var passwordMinimumNonLetterCharacters: Int?
    var passwordMinimumNumericCharacters: Int?
    var passwordMinimumSymbolCharacters: Int?
    var passwordMinimumUpperCaseCharacters: Int?
    var passwordMinutesOfInactivityBeforeScreenTimeout: Int?
    var passwordPreviousPasswordCountToBlock: Int?
    var passwordRequiredType: AndroidPasswordType = .deviceDefault
    var passwordRequireUnlock: PasswordUnlockTime = .deviceDefault
    var passwordSignInFailureCountBeforeFactoryReset: Int?

    // Personal Profile
    var personalProfileAppsAllowInstallFromUnknownSources: Bool = false
    var personalProfileCameraBlocked: Bool = false
    var personalProfileScreenCaptureBlocked: Bool = false
    var personalProfilePlayStoreMode: PersonalPlayStoreMode = .notConfigured
    var personalProfilePersonalApplications: [AppListItem] = []

    // Play Store Mode
    var playStoreMode: PlayStoreMode = .notConfigured

    // Privacy
    var screenCaptureBlocked: Bool = false

    // Safety
    var safeBootBlocked: Bool = false

    // Security
    var securityCommonCriteriaModeEnabled: Bool = false
    var securityDeveloperSettingsEnabled: Bool = false
    var securityRequireVerifyApps: Bool = true

    // Status Bar
    var statusBarBlocked: Bool = false

    // Stay on Modes
    var stayOnModes: [StayOnMode] = []

    // Storage
    var storageAllowUsb: Bool = true
    var storageBlockExternalMedia: Bool = false
    var storageBlockUsbFileTransfer: Bool = false

    // System Update
    var systemUpdateFreezePeriods: [FreezePeriod] = []
    var systemUpdateWindowStartMinutesAfterMidnight: Int?
    var systemUpdateWindowEndMinutesAfterMidnight: Int?
    var systemUpdateInstallType: SystemUpdateInstallType = .deviceDefault

    // Users and Accounts
    var usersBlockAdd: Bool = false
    var usersBlockRemove: Bool = false

    // Volume
    var volumeBlockAdjustment: Bool = false

    // VPN
    var vpnAlwaysOnLockdownMode: Bool = false
    var vpnAlwaysOnPackageIdentifier: String?

    // Wi-Fi
    var wifiBlockEditConfigurations: Bool = false
    var wifiBlockEditPolicyDefinedConfigurations: Bool = false
    var wiFiBlockWiFiDirect: Bool = false

    // Work Profile Password
    var workProfilePasswordExpirationDays: Int?
    var workProfilePasswordMinimumLength: Int?
    var workProfilePasswordMinimumNumericCharacters: Int?
    var workProfilePasswordMinimumNonLetterCharacters: Int?
    var workProfilePasswordMinimumLetterCharacters: Int?
    var workProfilePasswordMinimumLowerCaseCharacters: Int?
    var workProfilePasswordMinimumUpperCaseCharacters: Int?
    var workProfilePasswordMinimumSymbolCharacters: Int?
    var workProfilePasswordPreviousPasswordCountToBlock: Int?
    var workProfilePasswordSignInFailureCountBeforeFactoryReset: Int?
    var workProfilePasswordRequiredType: AndroidPasswordType = .deviceDefault
    var workProfilePasswordRequireUnlock: PasswordUnlockTime = .deviceDefault

    enum EnrollmentProfileType: String, Codable {
        case notConfigured = "notConfigured"
        case dedicatedDevice = "dedicatedDevice"
        case fullyManaged = "fullyManaged"
    }

    enum AppAutoUpdatePolicy: String, Codable {
        case notConfigured = "notConfigured"
        case userChoice = "userChoice"
        case never = "never"
        case wiFiOnly = "wiFiOnly"
        case always = "always"
    }

    enum AppPermissionPolicy: String, Codable {
        case deviceDefault = "deviceDefault"
        case prompt = "prompt"
        case autoGrant = "autoGrant"
        case autoDeny = "autoDeny"
    }

    enum DataSharingLevel: String, Codable {
        case crossProfileDataSharingUnspecified = "crossProfileDataSharingUnspecified"
        case dataSharingFromWorkToPersonalBlocked = "dataSharingFromWorkToPersonalBlocked"
        case crossProfileDataSharingBlocked = "crossProfileDataSharingBlocked"
    }

    enum VirtualHomeButtonType: String, Codable {
        case notConfigured = "notConfigured"
        case swipeUp = "swipeUp"
        case floating = "floating"
    }

    enum ScreenOrientation: String, Codable {
        case notConfigured = "notConfigured"
        case portrait = "portrait"
        case landscape = "landscape"
        case autoRotate = "autoRotate"
    }

    enum DockPresenceConfiguration: String, Codable {
        case notConfigured = "notConfigured"
        case show = "show"
        case hide = "hide"
        case disabled = "disabled"
    }

    enum SearchBarPlacement: String, Codable {
        case notConfigured = "notConfigured"
        case top = "top"
        case bottom = "bottom"
        case hide = "hide"
    }

    enum KeyguardFeature: String, Codable {
        case notConfigured = "notConfigured"
        case camera = "camera"
        case notifications = "notifications"
        case unredactedNotifications = "unredactedNotifications"
        case trustAgents = "trustAgents"
        case fingerprint = "fingerprint"
        case remoteInput = "remoteInput"
        case allFeatures = "allFeatures"
        case face = "face"
        case iris = "iris"
        case biometrics = "biometrics"
    }

    enum AndroidPasswordType: String, Codable {
        case deviceDefault = "deviceDefault"
        case required = "required"
        case numeric = "numeric"
        case numericComplex = "numericComplex"
        case alphabetic = "alphabetic"
        case alphanumeric = "alphanumeric"
        case alphanumericWithSymbols = "alphanumericWithSymbols"
        case lowSecurityBiometric = "lowSecurityBiometric"
        case customPassword = "customPassword"
    }

    enum PasswordUnlockTime: String, Codable {
        case deviceDefault = "deviceDefault"
        case daily = "daily"
        case unkownFutureValue = "unkownFutureValue"
    }

    enum PersonalPlayStoreMode: String, Codable {
        case notConfigured = "notConfigured"
        case blockedApps = "blockedApps"
        case allowedApps = "allowedApps"
    }

    enum PlayStoreMode: String, Codable {
        case notConfigured = "notConfigured"
        case allowList = "allowList"
        case blockList = "blockList"
    }

    enum StayOnMode: String, Codable {
        case notConfigured = "notConfigured"
        case ac = "ac"
        case usb = "usb"
        case wireless = "wireless"
    }

    enum SystemUpdateInstallType: String, Codable {
        case deviceDefault = "deviceDefault"
        case postpone = "postpone"
        case windowed = "windowed"
        case automatic = "automatic"
    }

    struct GlobalProxySettings: Codable {
        var proxyType: ProxyType
        var host: String?
        var port: Int?
        var pacUrl: String?
        var excludeList: [String] = []

        enum ProxyType: String, Codable {
            case notConfigured = "notConfigured"
            case manual = "manual"
            case automatic = "automatic"
        }
    }

    struct FreezePeriod: Codable {
        var startMonth: Int
        var startDay: Int
        var endMonth: Int
        var endDay: Int
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case enrollmentProfile
        case accountsBlockModification, accountsBlockAdd, accountsBlockRemove
        case appsAllowInstallFromUnknownSources, appsAutoUpdatePolicy
        case appsDefaultPermissionPolicy, appsRecommendSkippingFirstUseHints
        case appsAllowedList, appsBlockedList, appsHideList
        case appsInstallAllowList, appsUninstallBlockList
        case bluetoothBlockConfiguration, bluetoothBlockContactSharing
        case cameraBlocked
        case cellularBlockDataRoaming, cellularBlockVoiceRoaming, cellularBlockWiFiTethering
        case certificateCredentialConfigurationDisabled
        case crossProfilePoliciesAllowCopyPaste, crossProfilePoliciesAllowDataSharing
        case crossProfilePoliciesShowWorkContactsInPersonalProfile
        case dataRoamingBlocked, dateTimeConfigurationBlocked
        case factoryResetBlocked, factoryResetDeviceAdministratorEmails
        case globalProxy
        case googleAccountsBlocked, googlePlayStoreBlocked
        case kioskModeApps, kioskModeWallpaperUrl, kioskModeExitCode
        case kioskModeVirtualHomeButtonEnabled, kioskModeVirtualHomeButtonType
        case kioskModeBluetoothConfigurationEnabled, kioskModeDebugMenuEasyAccessEnabled
        case kioskModeShowAppNotificationBadge, kioskModeScreenOrientation
        case locationModeBlocked
        case microsoftLauncherConfigurationEnabled, microsoftLauncherCustomWallpaperEnabled
        case microsoftLauncherCustomWallpaperImageUrl, microsoftLauncherCustomWallpaperAllowUserModification
        case microsoftLauncherFeedEnabled, microsoftLauncherFeedAllowUserModification
        case microsoftLauncherDockPresenceConfiguration, microsoftLauncherDockPresenceAllowUserModification
        case microsoftLauncherSearchBarPlacementConfiguration
        case networkEscapeHatchAllowed, nfcBlockOutgoingBeam
        case passwordBlockKeyguard, passwordBlockKeyguardFeatures
        case passwordExpirationDays, passwordMinimumLength
        case passwordMinimumLetterCharacters, passwordMinimumLowerCaseCharacters
        case passwordMinimumNonLetterCharacters, passwordMinimumNumericCharacters
        case passwordMinimumSymbolCharacters, passwordMinimumUpperCaseCharacters
        case passwordMinutesOfInactivityBeforeScreenTimeout, passwordPreviousPasswordCountToBlock
        case passwordRequiredType, passwordRequireUnlock, passwordSignInFailureCountBeforeFactoryReset
        case personalProfileAppsAllowInstallFromUnknownSources, personalProfileCameraBlocked
        case personalProfileScreenCaptureBlocked, personalProfilePlayStoreMode
        case personalProfilePersonalApplications
        case playStoreMode
        case screenCaptureBlocked
        case safeBootBlocked
        case securityCommonCriteriaModeEnabled, securityDeveloperSettingsEnabled, securityRequireVerifyApps
        case statusBarBlocked
        case stayOnModes
        case storageAllowUsb, storageBlockExternalMedia, storageBlockUsbFileTransfer
        case systemUpdateFreezePeriods, systemUpdateWindowStartMinutesAfterMidnight
        case systemUpdateWindowEndMinutesAfterMidnight, systemUpdateInstallType
        case usersBlockAdd, usersBlockRemove
        case volumeBlockAdjustment
        case vpnAlwaysOnLockdownMode, vpnAlwaysOnPackageIdentifier
        case wifiBlockEditConfigurations, wifiBlockEditPolicyDefinedConfigurations, wiFiBlockWiFiDirect
        case workProfilePasswordExpirationDays, workProfilePasswordMinimumLength
        case workProfilePasswordMinimumNumericCharacters, workProfilePasswordMinimumNonLetterCharacters
        case workProfilePasswordMinimumLetterCharacters, workProfilePasswordMinimumLowerCaseCharacters
        case workProfilePasswordMinimumUpperCaseCharacters, workProfilePasswordMinimumSymbolCharacters
        case workProfilePasswordPreviousPasswordCountToBlock
        case workProfilePasswordSignInFailureCountBeforeFactoryReset
        case workProfilePasswordRequiredType, workProfilePasswordRequireUnlock
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.profileDescription = try container.decodeIfPresent(String.self, forKey: .profileDescription)
        // Decode all properties with defaults...
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profileDescription, forKey: .profileDescription)
        // Encode all properties...
    }
}