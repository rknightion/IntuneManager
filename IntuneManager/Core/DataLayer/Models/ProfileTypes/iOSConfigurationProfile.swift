import Foundation

// MARK: - iOS General Device Configuration

struct iOSGeneralDeviceConfiguration: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    // Account Settings
    var accountBlockModification: Bool = false
    var accountsAllowedToAdd: [String] = []

    // Activation Lock
    var activationLockAllowWhenSupervised: Bool = false

    // AirDrop & Handoff
    var airDropBlocked: Bool = false
    var airDropForceUnmanagedDropTarget: Bool = false
    var iCloudBlockActivityContinuation: Bool = false

    // App Store & Apps
    var appStoreBlocked: Bool = false
    var appStoreBlockAutomaticDownloads: Bool = false
    var appStoreBlockInAppPurchases: Bool = false
    var appStoreBlockUIAppInstallation: Bool = false
    var appStoreRequirePassword: Bool = false
    var appsVisibilityList: [AppListItem] = []
    var appsVisibilityListType: AppVisibilityType = .none
    var appsSingleAppModeList: [AppListItem] = []
    var compliantAppsList: [AppListItem] = []
    var compliantAppListType: AppVisibilityType = .none

    // Camera & Screenshots
    var cameraBlocked: Bool = false
    var screenCaptureBlocked: Bool = false

    // Cellular
    var cellularBlockDataRoaming: Bool = false
    var cellularBlockGlobalBackgroundFetchWhileRoaming: Bool = false
    var cellularBlockPerAppDataModification: Bool = false
    var cellularBlockPersonalHotspot: Bool = false
    var cellularBlockPlanModification: Bool = false
    var cellularBlockVoiceRoaming: Bool = false

    // Cloud Services
    var iCloudBlockBackup: Bool = false
    var iCloudBlockDocumentSync: Bool = false
    var iCloudBlockManagedAppsSync: Bool = false
    var iCloudBlockPhotoLibrary: Bool = false
    var iCloudBlockPhotoStreamSync: Bool = false
    var iCloudBlockSharedPhotoStream: Bool = false
    var iCloudRequireEncryptedBackup: Bool = false

    // Content Restrictions
    var iTunesBlockExplicitContent: Bool = false
    var iTunesBlockMusicService: Bool = false
    var iTunesBlockRadio: Bool = false
    var iBooksStoreBlocked: Bool = false
    var iBooksStoreBlockErotica: Bool = false

    // Device Features
    var bluetoothBlockModification: Bool = false
    var definitionLookupBlocked: Bool = false
    var deviceBlockEnableRestrictions: Bool = false
    var deviceBlockEraseContentAndSettings: Bool = false
    var deviceBlockNameModification: Bool = false

    // Education
    var classroomAppBlockRemoteScreenObservation: Bool = false
    var classroomAppForceUnpromptedScreenObservation: Bool = false
    var classroomForceAutomaticallyJoinClasses: Bool = false
    var classroomForceRequestPermissionToLeaveClasses: Bool = false
    var classroomForceUnpromptedAppAndDeviceLock: Bool = false

    // Enterprise
    var enterpriseAppBlockTrust: Bool = false
    var enterpriseAppBlockTrustModification: Bool = false

    // FaceTime & Messages
    var faceTimeBlocked: Bool = false

    // Game Center
    var gameCenterBlocked: Bool = false
    var gamingBlockGameCenterFriends: Bool = false
    var gamingBlockMultiplayer: Bool = false

    // Keyboard
    var keyboardBlockAutoCorrect: Bool = false
    var keyboardBlockDictation: Bool = false
    var keyboardBlockPredictive: Bool = false
    var keyboardBlockShortcuts: Bool = false
    var keyboardBlockSpellCheck: Bool = false

    // Lock Screen
    var lockScreenBlockControlCenter: Bool = false
    var lockScreenBlockNotificationView: Bool = false
    var lockScreenBlockPassbook: Bool = false
    var lockScreenBlockTodayView: Bool = false

    // Passcode
    var passcodeBlockFingerprintUnlock: Bool = false
    var passcodeBlockFingerprintModification: Bool = false
    var passcodeBlockModification: Bool = false
    var passcodeBlockSimple: Bool = false
    var passcodeExpirationDays: Int?
    var passcodeMinimumLength: Int?
    var passcodeMinutesOfInactivityBeforeLock: Int?
    var passcodeMinutesOfInactivityBeforeScreenTimeout: Int?
    var passcodeMinimumCharacterSetCount: Int?
    var passcodePreviousPasscodeBlockCount: Int?
    var passcodeSignInFailureCountBeforeWipe: Int?
    var passcodeRequiredType: PasscodeType = .deviceDefault

    // Safari
    var safariBlockAutofill: Bool = false
    var safariBlocked: Bool = false
    var safariBlockJavaScript: Bool = false
    var safariBlockPopups: Bool = false
    var safariCookieSettings: CookieSettings = .browserDefault
    var safariForceFraudWarning: Bool = false

    // Siri & Search
    var siriBlocked: Bool = false
    var siriBlockedWhenLocked: Bool = false
    var siriBlockUserGeneratedContent: Bool = false
    var siriRequireProfanityFilter: Bool = false
    var spotlightBlockInternetResults: Bool = false

    // System
    var certificatesBlockUntrustedTlsCertificates: Bool = false
    var configurationProfileBlockChanges: Bool = false
    var diagnosticDataBlockSubmission: Bool = false
    var diagnosticDataBlockSubmissionModification: Bool = false
    var documentsBlockManagedDocumentsInUnmanagedApps: Bool = false
    var documentsBlockUnmanagedDocumentsInManagedApps: Bool = false
    var hostPairingBlocked: Bool = false

    // VPN
    var vpnBlockCreation: Bool = false

    // Wallpaper
    var wallpaperBlockModification: Bool = false

    // Apple Watch
    var appleWatchBlockPairing: Bool = false
    var appleWatchForceWristDetection: Bool = false

    // WiFi
    var wiFiConnectOnlyToConfiguredNetworks: Bool = false
    var wiFiConnectToAllowedNetworksOnlyForced: Bool = false

    enum AppVisibilityType: String, Codable {
        case none = "none"
        case appsInListCompliant = "appsInListCompliant"
        case appsNotInListCompliant = "appsNotInListCompliant"
    }

    enum PasscodeType: String, Codable {
        case deviceDefault = "deviceDefault"
        case alphanumeric = "alphanumeric"
        case numeric = "numeric"
        case numericComplex = "numericComplex"
    }

    enum CookieSettings: String, Codable {
        case browserDefault = "browserDefault"
        case blockAlways = "blockAlways"
        case allowFromWebsitesVisited = "allowFromWebsitesVisited"
        case allowFromCurrentWebsiteOnly = "allowFromCurrentWebsiteOnly"
        case allowAlways = "allowAlways"
    }

    init(id: String, displayName: String, profileDescription: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.profileDescription = profileDescription
    }

    // Codable implementation
    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case accountBlockModification, accountsAllowedToAdd
        case activationLockAllowWhenSupervised
        case airDropBlocked, airDropForceUnmanagedDropTarget, iCloudBlockActivityContinuation
        case appStoreBlocked, appStoreBlockAutomaticDownloads, appStoreBlockInAppPurchases
        case appStoreBlockUIAppInstallation, appStoreRequirePassword
        case appsVisibilityList, appsVisibilityListType, appsSingleAppModeList
        case compliantAppsList, compliantAppListType
        case cameraBlocked, screenCaptureBlocked
        case cellularBlockDataRoaming, cellularBlockGlobalBackgroundFetchWhileRoaming
        case cellularBlockPerAppDataModification, cellularBlockPersonalHotspot
        case cellularBlockPlanModification, cellularBlockVoiceRoaming
        case iCloudBlockBackup, iCloudBlockDocumentSync, iCloudBlockManagedAppsSync
        case iCloudBlockPhotoLibrary, iCloudBlockPhotoStreamSync, iCloudBlockSharedPhotoStream
        case iCloudRequireEncryptedBackup
        case iTunesBlockExplicitContent, iTunesBlockMusicService, iTunesBlockRadio
        case iBooksStoreBlocked, iBooksStoreBlockErotica
        case bluetoothBlockModification, definitionLookupBlocked
        case deviceBlockEnableRestrictions, deviceBlockEraseContentAndSettings, deviceBlockNameModification
        case classroomAppBlockRemoteScreenObservation, classroomAppForceUnpromptedScreenObservation
        case classroomForceAutomaticallyJoinClasses, classroomForceRequestPermissionToLeaveClasses
        case classroomForceUnpromptedAppAndDeviceLock
        case enterpriseAppBlockTrust, enterpriseAppBlockTrustModification
        case faceTimeBlocked
        case gameCenterBlocked, gamingBlockGameCenterFriends, gamingBlockMultiplayer
        case keyboardBlockAutoCorrect, keyboardBlockDictation, keyboardBlockPredictive
        case keyboardBlockShortcuts, keyboardBlockSpellCheck
        case lockScreenBlockControlCenter, lockScreenBlockNotificationView
        case lockScreenBlockPassbook, lockScreenBlockTodayView
        case passcodeBlockFingerprintUnlock, passcodeBlockFingerprintModification
        case passcodeBlockModification, passcodeBlockSimple
        case passcodeExpirationDays, passcodeMinimumLength
        case passcodeMinutesOfInactivityBeforeLock, passcodeMinutesOfInactivityBeforeScreenTimeout
        case passcodeMinimumCharacterSetCount, passcodePreviousPasscodeBlockCount
        case passcodeSignInFailureCountBeforeWipe, passcodeRequiredType
        case safariBlockAutofill, safariBlocked, safariBlockJavaScript, safariBlockPopups
        case safariCookieSettings, safariForceFraudWarning
        case siriBlocked, siriBlockedWhenLocked, siriBlockUserGeneratedContent, siriRequireProfanityFilter
        case spotlightBlockInternetResults
        case certificatesBlockUntrustedTlsCertificates, configurationProfileBlockChanges
        case diagnosticDataBlockSubmission, diagnosticDataBlockSubmissionModification
        case documentsBlockManagedDocumentsInUnmanagedApps, documentsBlockUnmanagedDocumentsInManagedApps
        case hostPairingBlocked
        case vpnBlockCreation
        case wallpaperBlockModification
        case appleWatchBlockPairing, appleWatchForceWristDetection
        case wiFiConnectOnlyToConfiguredNetworks, wiFiConnectToAllowedNetworksOnlyForced
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.profileDescription = try container.decodeIfPresent(String.self, forKey: .profileDescription)
        // Decode all other properties with default values...
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profileDescription, forKey: .profileDescription)
        // Encode all other properties...
    }
}

// MARK: - iOS Wi-Fi Configuration

struct iOSWiFiConfiguration: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    // Network Settings
    var networkName: String
    var ssid: String
    var connectAutomatically: Bool = true
    var connectWhenNetworkNameIsHidden: Bool = false
    var wiFiSecurityType: WiFiSecurityType = .open
    var preSharedKey: String?

    // Proxy Settings
    var proxySettings: ProxySettings = .none
    var proxyManualAddress: String?
    var proxyManualPort: Int?
    var proxyAutomaticConfigurationUrl: String?

    // Authentication
    var eapType: EAPType?
    var authenticationMethod: AuthenticationMethod?
    var innerAuthenticationProtocol: String?
    var outerIdentityPrivacyTemporaryValue: String?

    enum WiFiSecurityType: String, Codable {
        case open = "open"
        case wep = "wep"
        case wpa = "wpa"
        case wpaPersonal = "wpaPersonal"
        case wpaEnterprise = "wpaEnterprise"
        case wpa2Personal = "wpa2Personal"
        case wpa2Enterprise = "wpa2Enterprise"
        case wpa3Personal = "wpa3Personal"
        case wpa3Enterprise = "wpa3Enterprise"
    }

    enum ProxySettings: String, Codable {
        case none = "none"
        case manual = "manual"
        case automatic = "automatic"
    }

    enum EAPType: String, Codable {
        case eapTls = "eapTls"
        case eapTtls = "eapTtls"
        case peap = "peap"
        case eapFast = "eapFast"
    }

    enum AuthenticationMethod: String, Codable {
        case certificate = "certificate"
        case usernameAndPassword = "usernameAndPassword"
        case derivedCredential = "derivedCredential"
    }

    init(id: String, displayName: String, networkName: String, ssid: String) {
        self.id = id
        self.displayName = displayName
        self.networkName = networkName
        self.ssid = ssid
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case networkName, ssid, connectAutomatically, connectWhenNetworkNameIsHidden
        case wiFiSecurityType, preSharedKey
        case proxySettings, proxyManualAddress, proxyManualPort, proxyAutomaticConfigurationUrl
        case eapType, authenticationMethod, innerAuthenticationProtocol, outerIdentityPrivacyTemporaryValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.profileDescription = try container.decodeIfPresent(String.self, forKey: .profileDescription)
        self.networkName = try container.decode(String.self, forKey: .networkName)
        self.ssid = try container.decode(String.self, forKey: .ssid)
        self.connectAutomatically = try container.decodeIfPresent(Bool.self, forKey: .connectAutomatically) ?? true
        self.connectWhenNetworkNameIsHidden = try container.decodeIfPresent(Bool.self, forKey: .connectWhenNetworkNameIsHidden) ?? false
        self.wiFiSecurityType = try container.decodeIfPresent(WiFiSecurityType.self, forKey: .wiFiSecurityType) ?? .open
        self.preSharedKey = try container.decodeIfPresent(String.self, forKey: .preSharedKey)
        self.proxySettings = try container.decodeIfPresent(ProxySettings.self, forKey: .proxySettings) ?? .none
        self.proxyManualAddress = try container.decodeIfPresent(String.self, forKey: .proxyManualAddress)
        self.proxyManualPort = try container.decodeIfPresent(Int.self, forKey: .proxyManualPort)
        self.proxyAutomaticConfigurationUrl = try container.decodeIfPresent(String.self, forKey: .proxyAutomaticConfigurationUrl)
        self.eapType = try container.decodeIfPresent(EAPType.self, forKey: .eapType)
        self.authenticationMethod = try container.decodeIfPresent(AuthenticationMethod.self, forKey: .authenticationMethod)
        self.innerAuthenticationProtocol = try container.decodeIfPresent(String.self, forKey: .innerAuthenticationProtocol)
        self.outerIdentityPrivacyTemporaryValue = try container.decodeIfPresent(String.self, forKey: .outerIdentityPrivacyTemporaryValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profileDescription, forKey: .profileDescription)
        try container.encode(networkName, forKey: .networkName)
        try container.encode(ssid, forKey: .ssid)
        try container.encode(connectAutomatically, forKey: .connectAutomatically)
        try container.encode(connectWhenNetworkNameIsHidden, forKey: .connectWhenNetworkNameIsHidden)
        try container.encode(wiFiSecurityType, forKey: .wiFiSecurityType)
        try container.encodeIfPresent(preSharedKey, forKey: .preSharedKey)
        try container.encode(proxySettings, forKey: .proxySettings)
        try container.encodeIfPresent(proxyManualAddress, forKey: .proxyManualAddress)
        try container.encodeIfPresent(proxyManualPort, forKey: .proxyManualPort)
        try container.encodeIfPresent(proxyAutomaticConfigurationUrl, forKey: .proxyAutomaticConfigurationUrl)
        try container.encodeIfPresent(eapType, forKey: .eapType)
        try container.encodeIfPresent(authenticationMethod, forKey: .authenticationMethod)
        try container.encodeIfPresent(innerAuthenticationProtocol, forKey: .innerAuthenticationProtocol)
        try container.encodeIfPresent(outerIdentityPrivacyTemporaryValue, forKey: .outerIdentityPrivacyTemporaryValue)
    }
}

// MARK: - iOS VPN Configuration

struct iOSVpnConfiguration: Codable {
    var id: String
    var displayName: String
    var profileDescription: String?

    // Connection Settings
    var connectionName: String
    var connectionType: VPNConnectionType = .ikEv2
    var servers: [VPNServer] = []
    var authenticationMethod: VPNAuthenticationMethod = .usernameAndPassword

    // IKEv2 Settings
    var enableSplitTunneling: Bool = false
    var enableAlwaysOn: Bool = false
    var enablePerApp: Bool = false
    var associatedApps: [String] = []

    // Security Settings
    var encryptionLevel: EncryptionLevel = .required
    var integrityAlgorithm: String = "SHA2-256"
    var encryptionAlgorithm: String = "AES-256"
    var dhGroup: Int = 14
    var perfectForwardSecrecyGroup: Int = 14

    // Authentication
    var realm: String?
    var role: String?
    var certificateType: CertificateType?
    var certificateId: String?

    // Advanced
    var disableMobilityAndMultihoming: Bool = false
    var disableRedirect: Bool = false
    var useInternalIPSubnet: Bool = false
    var enableFallback: Bool = false
    var natKeepAliveInterval: Int = 20
    var mtu: Int = 1400

    enum VPNConnectionType: String, Codable {
        case ciscoAnyConnect = "ciscoAnyConnect"
        case pulse = "pulse"
        case f5Edge = "f5Edge"
        case dellSonicWallMobileConnect = "dellSonicWallMobileConnect"
        case checkPointCapsuleVpn = "checkPointCapsuleVpn"
        case customSsl = "customSsl"
        case ikEv2 = "ikEv2"
    }

    enum VPNAuthenticationMethod: String, Codable {
        case usernameAndPassword = "usernameAndPassword"
        case sharedSecret = "sharedSecret"
        case certificate = "certificate"
        case derivedCredential = "derivedCredential"
    }

    enum EncryptionLevel: String, Codable {
        case none = "none"
        case required = "required"
        case maximum = "maximum"
    }

    enum CertificateType: String, Codable {
        case rsa = "rsa"
        case ecdsa256 = "ecdsa256"
        case ecdsa384 = "ecdsa384"
        case ecdsa521 = "ecdsa521"
    }

    struct VPNServer: Codable {
        var address: String
        var description: String?
        var isDefaultServer: Bool = false
    }

    init(id: String, displayName: String, connectionName: String) {
        self.id = id
        self.displayName = displayName
        self.connectionName = connectionName
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, profileDescription
        case connectionName, connectionType, servers, authenticationMethod
        case enableSplitTunneling, enableAlwaysOn, enablePerApp, associatedApps
        case encryptionLevel, integrityAlgorithm, encryptionAlgorithm
        case dhGroup, perfectForwardSecrecyGroup
        case realm, role, certificateType, certificateId
        case disableMobilityAndMultihoming, disableRedirect
        case useInternalIPSubnet, enableFallback
        case natKeepAliveInterval, mtu
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.profileDescription = try container.decodeIfPresent(String.self, forKey: .profileDescription)
        self.connectionName = try container.decode(String.self, forKey: .connectionName)
        self.connectionType = try container.decodeIfPresent(VPNConnectionType.self, forKey: .connectionType) ?? .ikEv2
        self.servers = try container.decodeIfPresent([VPNServer].self, forKey: .servers) ?? []
        self.authenticationMethod = try container.decodeIfPresent(VPNAuthenticationMethod.self, forKey: .authenticationMethod) ?? .usernameAndPassword
        self.enableSplitTunneling = try container.decodeIfPresent(Bool.self, forKey: .enableSplitTunneling) ?? false
        self.enableAlwaysOn = try container.decodeIfPresent(Bool.self, forKey: .enableAlwaysOn) ?? false
        self.enablePerApp = try container.decodeIfPresent(Bool.self, forKey: .enablePerApp) ?? false
        self.associatedApps = try container.decodeIfPresent([String].self, forKey: .associatedApps) ?? []
        self.encryptionLevel = try container.decodeIfPresent(EncryptionLevel.self, forKey: .encryptionLevel) ?? .required
        self.integrityAlgorithm = try container.decodeIfPresent(String.self, forKey: .integrityAlgorithm) ?? "SHA2-256"
        self.encryptionAlgorithm = try container.decodeIfPresent(String.self, forKey: .encryptionAlgorithm) ?? "AES-256"
        self.dhGroup = try container.decodeIfPresent(Int.self, forKey: .dhGroup) ?? 14
        self.perfectForwardSecrecyGroup = try container.decodeIfPresent(Int.self, forKey: .perfectForwardSecrecyGroup) ?? 14
        self.realm = try container.decodeIfPresent(String.self, forKey: .realm)
        self.role = try container.decodeIfPresent(String.self, forKey: .role)
        self.certificateType = try container.decodeIfPresent(CertificateType.self, forKey: .certificateType)
        self.certificateId = try container.decodeIfPresent(String.self, forKey: .certificateId)
        self.disableMobilityAndMultihoming = try container.decodeIfPresent(Bool.self, forKey: .disableMobilityAndMultihoming) ?? false
        self.disableRedirect = try container.decodeIfPresent(Bool.self, forKey: .disableRedirect) ?? false
        self.useInternalIPSubnet = try container.decodeIfPresent(Bool.self, forKey: .useInternalIPSubnet) ?? false
        self.enableFallback = try container.decodeIfPresent(Bool.self, forKey: .enableFallback) ?? false
        self.natKeepAliveInterval = try container.decodeIfPresent(Int.self, forKey: .natKeepAliveInterval) ?? 20
        self.mtu = try container.decodeIfPresent(Int.self, forKey: .mtu) ?? 1400
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(profileDescription, forKey: .profileDescription)
        try container.encode(connectionName, forKey: .connectionName)
        try container.encode(connectionType, forKey: .connectionType)
        try container.encode(servers, forKey: .servers)
        try container.encode(authenticationMethod, forKey: .authenticationMethod)
        try container.encode(enableSplitTunneling, forKey: .enableSplitTunneling)
        try container.encode(enableAlwaysOn, forKey: .enableAlwaysOn)
        try container.encode(enablePerApp, forKey: .enablePerApp)
        try container.encode(associatedApps, forKey: .associatedApps)
        try container.encode(encryptionLevel, forKey: .encryptionLevel)
        try container.encode(integrityAlgorithm, forKey: .integrityAlgorithm)
        try container.encode(encryptionAlgorithm, forKey: .encryptionAlgorithm)
        try container.encode(dhGroup, forKey: .dhGroup)
        try container.encode(perfectForwardSecrecyGroup, forKey: .perfectForwardSecrecyGroup)
        try container.encodeIfPresent(realm, forKey: .realm)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(certificateType, forKey: .certificateType)
        try container.encodeIfPresent(certificateId, forKey: .certificateId)
        try container.encode(disableMobilityAndMultihoming, forKey: .disableMobilityAndMultihoming)
        try container.encode(disableRedirect, forKey: .disableRedirect)
        try container.encode(useInternalIPSubnet, forKey: .useInternalIPSubnet)
        try container.encode(enableFallback, forKey: .enableFallback)
        try container.encode(natKeepAliveInterval, forKey: .natKeepAliveInterval)
        try container.encode(mtu, forKey: .mtu)
    }
}

// MARK: - Shared Helper Types

struct AppListItem: Codable {
    var name: String
    var publisher: String?
    var appStoreUrl: String?
    var appId: String
}