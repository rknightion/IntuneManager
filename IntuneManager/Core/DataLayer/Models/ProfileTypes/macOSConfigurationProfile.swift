import Foundation

// MARK: - macOS General Device Configuration

struct macOSGeneralDeviceConfiguration: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    // Compliant Apps
    var compliantAppsList: [AppListItem] = []
    var compliantAppListType: AppListType = .none

    // Email
    var emailInDomainSuffixes: [String] = []

    // Password Settings
    var passwordBlockSimple: Bool = false
    var passwordExpirationDays: Int?
    var passwordMinimumCharacterSetCount: Int?
    var passwordMinimumLength: Int?
    var passwordMinutesOfInactivityBeforeLock: Int?
    var passwordMinutesOfInactivityBeforeScreenTimeout: Int?
    var passwordPreviousPasswordBlockCount: Int?
    var passwordRequiredType: PasswordType = .deviceDefault
    var passwordRequired: Bool = false
    var passwordMaximumAttemptCount: Int?
    var passwordMinutesUntilFailedLoginReset: Int?
    var passwordBlockFingerprintUnlock: Bool = false
    var passwordBlockAutoFill: Bool = false
    var passwordBlockProximityRequests: Bool = false
    var passwordBlockAirDropSharing: Bool = false

    // Keychain & iCloud
    var keychainBlockCloudSync: Bool = false
    var iCloudBlockDocumentSync: Bool = false
    var iCloudBlockMail: Bool = false
    var iCloudBlockAddressBook: Bool = false
    var iCloudBlockCalendar: Bool = false
    var iCloudBlockReminders: Bool = false
    var iCloudBlockBookmarks: Bool = false
    var iCloudBlockNotes: Bool = false
    var iCloudBlockPhotoLibrary: Bool = false
    var iCloudBlockActivityContinuation: Bool = false
    var iCloudPrivateRelayBlocked: Bool = false
    var iCloudDesktopAndDocumentsBlocked: Bool = false

    // Safari
    var safariBlockAutofill: Bool = false

    // Device Features
    var cameraBlocked: Bool = false
    var screenCaptureBlocked: Bool = false
    var airDropBlocked: Bool = false
    var spotlightBlockInternetResults: Bool = false
    var definitionLookupBlocked: Bool = false

    // iTunes & Media
    var iTunesBlockMusicService: Bool = false
    var iTunesBlockFileSharing: Bool = false

    // Apple Watch
    var appleWatchBlockAutoUnlock: Bool = false

    // Software Updates
    var softwareUpdatesEnforcedDelayInDays: Int?
    var updateDelayPolicy: UpdateDelayPolicy?
    var softwareUpdateMajorOSDeferredInstallDelayInDays: Int?
    var softwareUpdateMinorOSDeferredInstallDelayInDays: Int?
    var softwareUpdateNonOSDeferredInstallDelayInDays: Int?

    // Content Caching
    var contentCachingBlocked: Bool = false

    // Classroom
    var classroomAppBlockRemoteScreenObservation: Bool = false
    var classroomAppForceUnpromptedScreenObservation: Bool = false
    var classroomForceAutomaticallyJoinClasses: Bool = false
    var classroomForceRequestPermissionToLeaveClasses: Bool = false
    var classroomForceUnpromptedAppAndDeviceLock: Bool = false

    // Privacy Access Controls
    var privacyAccessControls: [PrivacyAccessControlItem] = []

    // Game Center
    var addingGameCenterFriendsBlocked: Bool = false
    var gameCenterBlocked: Bool = false
    var multiplayerGamingBlocked: Bool = false

    // System
    var wallpaperModificationBlocked: Bool = false
    var eraseContentAndSettingsBlocked: Bool = false
    var activationLockWhenSupervisedAllowed: Bool = false
    var touchIdTimeoutInHours: Int = 48

    enum AppListType: String, Codable {
        case none = "none"
        case appsInListCompliant = "appsInListCompliant"
        case appsNotInListCompliant = "appsNotInListCompliant"
    }

    enum PasswordType: String, Codable {
        case deviceDefault = "deviceDefault"
        case alphanumeric = "alphanumeric"
        case numeric = "numeric"
    }

    enum UpdateDelayPolicy: String, Codable {
        case none = "none"
        case delayOSUpdateVisibility = "delayOSUpdateVisibility"
        case delayAppUpdateVisibility = "delayAppUpdateVisibility"
        case delayMajorOsUpdateVisibility = "delayMajorOsUpdateVisibility"
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case compliantAppsList, compliantAppListType
        case emailInDomainSuffixes
        case passwordBlockSimple, passwordExpirationDays, passwordMinimumCharacterSetCount
        case passwordMinimumLength, passwordMinutesOfInactivityBeforeLock
        case passwordMinutesOfInactivityBeforeScreenTimeout, passwordPreviousPasswordBlockCount
        case passwordRequiredType, passwordRequired, passwordMaximumAttemptCount
        case passwordMinutesUntilFailedLoginReset, passwordBlockFingerprintUnlock
        case passwordBlockAutoFill, passwordBlockProximityRequests, passwordBlockAirDropSharing
        case keychainBlockCloudSync
        case iCloudBlockDocumentSync, iCloudBlockMail, iCloudBlockAddressBook
        case iCloudBlockCalendar, iCloudBlockReminders, iCloudBlockBookmarks
        case iCloudBlockNotes, iCloudBlockPhotoLibrary, iCloudBlockActivityContinuation
        case iCloudPrivateRelayBlocked, iCloudDesktopAndDocumentsBlocked
        case safariBlockAutofill
        case cameraBlocked, screenCaptureBlocked, airDropBlocked
        case spotlightBlockInternetResults, definitionLookupBlocked
        case iTunesBlockMusicService, iTunesBlockFileSharing
        case appleWatchBlockAutoUnlock
        case softwareUpdatesEnforcedDelayInDays, updateDelayPolicy
        case softwareUpdateMajorOSDeferredInstallDelayInDays
        case softwareUpdateMinorOSDeferredInstallDelayInDays
        case softwareUpdateNonOSDeferredInstallDelayInDays
        case contentCachingBlocked
        case classroomAppBlockRemoteScreenObservation, classroomAppForceUnpromptedScreenObservation
        case classroomForceAutomaticallyJoinClasses, classroomForceRequestPermissionToLeaveClasses
        case classroomForceUnpromptedAppAndDeviceLock
        case privacyAccessControls
        case addingGameCenterFriendsBlocked, gameCenterBlocked, multiplayerGamingBlocked
        case wallpaperModificationBlocked, eraseContentAndSettingsBlocked
        case activationLockWhenSupervisedAllowed, touchIdTimeoutInHours
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

// MARK: - macOS Endpoint Protection Configuration

struct macOSEndpointProtectionConfiguration: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    // Gatekeeper
    var gatekeeperAllowedAppSource: GatekeeperAppSource = .macAppStore
    var gatekeeperBlockOverride: Bool = false

    // FileVault
    var fileVaultEnabled: Bool = false
    var fileVaultSelectedRecoveryKeyTypes: FileVaultRecoveryKeyType = .personalRecoveryKey
    var fileVaultInstitutionalRecoveryKeyCertificate: String?
    var fileVaultInstitutionalRecoveryKeyCertificateFileName: String?
    var fileVaultPersonalRecoveryKeyHelpMessage: String?
    var fileVaultAllowDeferralUntilSignOut: Bool = false
    var fileVaultNumberOfTimesUserCanIgnore: Int?
    var fileVaultDisablePromptAtSignOut: Bool = false
    var fileVaultPersonalRecoveryKeyRotationInMonths: Int?
    var fileVaultHidePersonalRecoveryKey: Bool = false

    // Firewall
    var firewallEnabled: Bool = false
    var firewallBlockAllIncoming: Bool = false
    var firewallEnableStealthMode: Bool = false
    var firewallApplications: [FirewallApplication] = []

    // Advanced Threat Protection
    var advancedThreatProtectionRealTime: Bool = false
    var advancedThreatProtectionCloudDelivered: Bool = false
    var advancedThreatProtectionAutomaticSampleSubmission: Bool = false
    var advancedThreatProtectionDiagnosticDataCollection: Bool = false
    var advancedThreatProtectionExcludedFolders: [String] = []
    var advancedThreatProtectionExcludedFiles: [String] = []
    var advancedThreatProtectionExcludedExtensions: [String] = []
    var advancedThreatProtectionExcludedProcesses: [String] = []

    enum GatekeeperAppSource: String, Codable {
        case notConfigured = "notConfigured"
        case macAppStore = "macAppStore"
        case macAppStoreAndIdentifiedDevelopers = "macAppStoreAndIdentifiedDevelopers"
        case anywhere = "anywhere"
    }

    enum FileVaultRecoveryKeyType: String, Codable {
        case notConfigured = "notConfigured"
        case institutionalRecoveryKey = "institutionalRecoveryKey"
        case personalRecoveryKey = "personalRecoveryKey"
    }

    struct FirewallApplication: Codable {
        var bundleId: String
        var allowsIncomingConnections: Bool
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case gatekeeperAllowedAppSource, gatekeeperBlockOverride
        case fileVaultEnabled, fileVaultSelectedRecoveryKeyTypes
        case fileVaultInstitutionalRecoveryKeyCertificate
        case fileVaultInstitutionalRecoveryKeyCertificateFileName
        case fileVaultPersonalRecoveryKeyHelpMessage
        case fileVaultAllowDeferralUntilSignOut
        case fileVaultNumberOfTimesUserCanIgnore
        case fileVaultDisablePromptAtSignOut
        case fileVaultPersonalRecoveryKeyRotationInMonths
        case fileVaultHidePersonalRecoveryKey
        case firewallEnabled, firewallBlockAllIncoming
        case firewallEnableStealthMode, firewallApplications
        case advancedThreatProtectionRealTime, advancedThreatProtectionCloudDelivered
        case advancedThreatProtectionAutomaticSampleSubmission
        case advancedThreatProtectionDiagnosticDataCollection
        case advancedThreatProtectionExcludedFolders, advancedThreatProtectionExcludedFiles
        case advancedThreatProtectionExcludedExtensions, advancedThreatProtectionExcludedProcesses
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

// MARK: - macOS Privacy Preferences Policy Control

struct macOSPrivacyPreferencesPolicyControl: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    var privacyPreferencesPolicyControls: [PrivacyPreferenceItem] = []

    struct PrivacyPreferenceItem: Codable {
        var identifier: String
        var identifierType: IdentifierType
        var codeRequirement: String?
        var staticCodeValidation: Bool = false
        var accessibility: PrivacyPreferenceValue = .notConfigured
        var addressBook: PrivacyPreferenceValue = .notConfigured
        var appleEventsAllowedReceivers: [AppleEventReceiver] = []
        var calendar: PrivacyPreferenceValue = .notConfigured
        var camera: PrivacyPreferenceValue = .notConfigured
        var fileProviderPresence: PrivacyPreferenceValue = .notConfigured
        var listenEvent: PrivacyPreferenceValue = .notConfigured
        var mediaLibrary: PrivacyPreferenceValue = .notConfigured
        var microphone: PrivacyPreferenceValue = .notConfigured
        var photos: PrivacyPreferenceValue = .notConfigured
        var postEvent: PrivacyPreferenceValue = .notConfigured
        var reminders: PrivacyPreferenceValue = .notConfigured
        var screenCapture: PrivacyPreferenceValue = .notConfigured
        var speechRecognition: PrivacyPreferenceValue = .notConfigured
        var systemPolicyAllFiles: PrivacyPreferenceValue = .notConfigured
        var systemPolicyDesktopFolder: PrivacyPreferenceValue = .notConfigured
        var systemPolicyDocumentsFolder: PrivacyPreferenceValue = .notConfigured
        var systemPolicyDownloadsFolder: PrivacyPreferenceValue = .notConfigured
        var systemPolicyNetworkVolumes: PrivacyPreferenceValue = .notConfigured
        var systemPolicyRemovableVolumes: PrivacyPreferenceValue = .notConfigured
        var systemPolicySystemAdminFiles: PrivacyPreferenceValue = .notConfigured

        enum IdentifierType: String, Codable {
            case bundleId = "bundleID"
            case path = "path"
        }

        enum PrivacyPreferenceValue: String, Codable {
            case notConfigured = "notConfigured"
            case allow = "allow"
            case deny = "deny"
        }

        struct AppleEventReceiver: Codable {
            var identifier: String
            var identifierType: IdentifierType
            var codeRequirement: String?
            var allowed: Bool
        }
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case privacyPreferencesPolicyControls
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.profileDescription = try container.decodeIfPresent(String.self, forKey: .profileDescription)
        self.privacyPreferencesPolicyControls = try container.decodeIfPresent([PrivacyPreferenceItem].self, forKey: .privacyPreferencesPolicyControls) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profileDescription, forKey: .profileDescription)
        try container.encode(privacyPreferencesPolicyControls, forKey: .privacyPreferencesPolicyControls)
    }
}

// MARK: - macOS Kernel Extensions

struct macOSKernelExtensionConfiguration: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    var kernelExtensionAllowedTeamIdentifiers: [String] = []
    var kernelExtensionsAllowed: [KernelExtension] = []
    var kernelExtensionOverridesAllowed: Bool = false
    var kernelExtensionUserConsentSettings: UserConsentSettings = .notConfigured

    struct KernelExtension: Codable {
        var teamIdentifier: String
        var bundleId: String
    }

    enum UserConsentSettings: String, Codable {
        case notConfigured = "notConfigured"
        case forceUserConsent = "forceUserConsent"
        case allowUserOverrides = "allowUserOverrides"
    }

    init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case kernelExtensionAllowedTeamIdentifiers
        case kernelExtensionsAllowed
        case kernelExtensionOverridesAllowed
        case kernelExtensionUserConsentSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.profileDescription = try container.decodeIfPresent(String.self, forKey: .profileDescription)
        self.kernelExtensionAllowedTeamIdentifiers = try container.decodeIfPresent([String].self, forKey: .kernelExtensionAllowedTeamIdentifiers) ?? []
        self.kernelExtensionsAllowed = try container.decodeIfPresent([KernelExtension].self, forKey: .kernelExtensionsAllowed) ?? []
        self.kernelExtensionOverridesAllowed = try container.decodeIfPresent(Bool.self, forKey: .kernelExtensionOverridesAllowed) ?? false
        self.kernelExtensionUserConsentSettings = try container.decodeIfPresent(UserConsentSettings.self, forKey: .kernelExtensionUserConsentSettings) ?? .notConfigured
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profileDescription, forKey: .profileDescription)
        try container.encode(kernelExtensionAllowedTeamIdentifiers, forKey: .kernelExtensionAllowedTeamIdentifiers)
        try container.encode(kernelExtensionsAllowed, forKey: .kernelExtensionsAllowed)
        try container.encode(kernelExtensionOverridesAllowed, forKey: .kernelExtensionOverridesAllowed)
        try container.encode(kernelExtensionUserConsentSettings, forKey: .kernelExtensionUserConsentSettings)
    }
}

// MARK: - Shared Types

struct PrivacyAccessControlItem: Codable {
    var displayName: String
    var identifier: String
    var identifierType: IdentifierType
    var codeRequirement: String?
    var staticCodeValidation: Bool = false
    var blockCamera: Bool = false
    var blockMicrophone: Bool = false
    var blockScreenCapture: Bool = false
    var blockListenEvent: Bool = false
    var speechRecognition: AccessLevel = .notConfigured
    var accessibility: AccessLevel = .notConfigured
    var addressBook: AccessLevel = .notConfigured
    var calendar: AccessLevel = .notConfigured
    var reminders: AccessLevel = .notConfigured
    var photos: AccessLevel = .notConfigured
    var mediaLibrary: AccessLevel = .notConfigured
    var fileProviderPresence: AccessLevel = .notConfigured
    var systemPolicyAllFiles: AccessLevel = .notConfigured
    var systemPolicySystemAdminFiles: AccessLevel = .notConfigured
    var systemPolicyDesktopFolder: AccessLevel = .notConfigured
    var systemPolicyDocumentsFolder: AccessLevel = .notConfigured
    var systemPolicyDownloadsFolder: AccessLevel = .notConfigured
    var systemPolicyNetworkVolumes: AccessLevel = .notConfigured
    var systemPolicyRemovableVolumes: AccessLevel = .notConfigured
    var postEvent: AccessLevel = .notConfigured
    var appleEventsAllowedReceivers: [AppleEventReceiver] = []

    enum IdentifierType: String, Codable {
        case bundleId = "bundleID"
        case path = "path"
    }

    enum AccessLevel: String, Codable {
        case notConfigured = "notConfigured"
        case enabled = "enabled"
        case disabled = "disabled"
    }

    struct AppleEventReceiver: Codable {
        var codeRequirement: String
        var identifier: String
        var identifierType: IdentifierType
        var allowed: Bool
    }
}