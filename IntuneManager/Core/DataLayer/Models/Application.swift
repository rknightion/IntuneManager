import Foundation
import SwiftData

@Model
final class Application: Identifiable, Codable, Hashable {
    @Attribute(.unique) var id: String
    var displayName: String
    var appDescription: String?
    var publisher: String?
    var largeIcon: MimeContent?
    var createdDateTime: Date
    var lastModifiedDateTime: Date
    var isFeatured: Bool
    var privacyInformationUrl: String?
    var informationUrl: String?
    var owner: String?
    var developer: String?
    var notes: String?
    var publishingState: PublishingState
    var appType: AppType
    var version: String?
    var fileName: String?
    var size: Int64?
    var minimumSupportedOperatingSystem: MinimumOS?
    var bundleId: String?
    var appStoreUrl: String?
    var applicableDeviceType: ApplicableDeviceType?
    var installCommandLine: String?
    var uninstallCommandLine: String?
    var ignoreVersionDetection: Bool

    // Assignment related
    var assignments: [AppAssignment]?
    var installSummary: InstallSummary?

    // MARK: - Platform Compatibility Helpers

    /// Returns the platforms this app supports based on its type
    var supportedPlatforms: Set<DevicePlatform> {
        switch appType {
        case .macOS, .macOSLobApp, .managedMacOSStoreApp, .macOSOfficeSuiteApp, .macOSPkgApp, .macOSDmgApp, .macOSMicrosoftDefenderApp:
            return [.macOS]
        case .iOS, .iosLobApp, .managedIOSStoreApp, .iosStoreApp:
            // iOS apps without VPP info default to iPhone/iPad
            return [.iOS, .iPadOS]
        case .iosVppApp:
            // VPP apps use applicableDeviceType if available
            if let deviceType = applicableDeviceType {
                var platforms: Set<DevicePlatform> = []
                if deviceType.iPhoneAndIPod { platforms.insert(.iOS) }
                if deviceType.iPad { platforms.insert(.iPadOS) }
                if deviceType.mac { platforms.insert(.macOS) }
                return platforms.isEmpty ? [.iOS, .iPadOS] : platforms
            }
            return [.iOS, .iPadOS]
        case .macOSVppApp:
            // macOS VPP apps might also support iOS via Catalyst
            if let deviceType = applicableDeviceType {
                var platforms: Set<DevicePlatform> = []
                if deviceType.mac { platforms.insert(.macOS) }
                if deviceType.iPhoneAndIPod { platforms.insert(.iOS) }
                if deviceType.iPad { platforms.insert(.iPadOS) }
                return platforms.isEmpty ? [.macOS] : platforms
            }
            return [.macOS]
        case .webApp, .windowsWebApp:
            // Web apps can run on any platform
            return [.macOS, .iOS, .iPadOS, .windows, .android]
        case .androidStoreApp, .androidManagedStoreApp:
            return [.android]
        case .windowsMobileMSI, .winAppX, .win32LobApp, .microsoftEdgeApp, .microsoftStoreForBusinessApp, .windowsUniversalAppX, .winGetApp, .win32CatalogApp, .microsoftDefenderForEndpoint:
            return [.windows]
        case .officeSuiteApp:
            // Office suite apps typically support Windows and sometimes Mac
            return [.windows, .macOS]
        case .unknown:
            // Unknown apps - be conservative
            return []
        }
    }

    /// Check if this app is compatible with a specific device OS
    func isCompatibleWith(deviceOS: String) -> Bool {
        let devicePlatform = DevicePlatform(from: deviceOS)
        return supportedPlatforms.contains(devicePlatform)
    }

    /// Returns a human-readable string of supported platforms
    var supportedPlatformsDescription: String {
        let platforms = supportedPlatforms.sorted { $0.rawValue < $1.rawValue }
        if platforms.isEmpty {
            return "Unknown"
        }
        return platforms.map { $0.displayName }.joined(separator: ", ")
    }

    enum DevicePlatform: String, CaseIterable {
        case macOS = "macOS"
        case iOS = "iOS"
        case iPadOS = "iPadOS"
        case windows = "Windows"
        case android = "Android"
        case linux = "Linux"
        case unknown = "Unknown"

        init(from operatingSystem: String) {
            switch operatingSystem.lowercased() {
            case "macos":
                self = .macOS
            case "ios":
                self = .iOS
            case "ipados":
                self = .iPadOS
            case "windows", "windows 10", "windows 11":
                self = .windows
            case "android":
                self = .android
            case "linux":
                self = .linux
            default:
                self = .unknown
            }
        }

        var displayName: String {
            switch self {
            case .macOS: return "macOS"
            case .iOS: return "iOS"
            case .iPadOS: return "iPadOS"
            case .windows: return "Windows"
            case .android: return "Android"
            case .linux: return "Linux"
            case .unknown: return "Unknown"
            }
        }

        var icon: String {
            switch self {
            case .macOS: return "desktopcomputer"
            case .iOS: return "iphone"
            case .iPadOS: return "ipad"
            case .windows: return "pc"
            case .android: return "phone.badge.checkmark"
            case .linux: return "terminal"
            case .unknown: return "questionmark"
            }
        }
    }

    enum PublishingState: String, Codable, CaseIterable {
        case notPublished
        case processing
        case published

        var displayName: String {
            switch self {
            case .notPublished: return "Not Published"
            case .processing: return "Processing"
            case .published: return "Published"
            }
        }
    }

    enum AppType: String, Codable, CaseIterable {
        case macOS
        case iOS
        case macOSLobApp
        case iosLobApp
        case iosVppApp
        case macOSVppApp
        case managedIOSStoreApp
        case managedMacOSStoreApp
        case macOSOfficeSuiteApp
        case webApp
        case macOSPkgApp
        case macOSDmgApp
        case iosStoreApp
        case androidStoreApp
        case androidManagedStoreApp
        case windowsMobileMSI
        case winAppX
        case win32LobApp
        case microsoftEdgeApp
        // Additional Windows app types
        case microsoftStoreForBusinessApp
        case windowsUniversalAppX
        case winGetApp
        case officeSuiteApp
        case windowsWebApp
        case win32CatalogApp  // Windows catalog app (Enterprise App Catalog)
        case microsoftDefenderForEndpoint  // Microsoft Defender for Endpoint onboarding
        case macOSMicrosoftDefenderApp  // macOS Microsoft Defender app
        case unknown  // For any unrecognized app types

        var displayName: String {
            switch self {
            case .macOS: return "macOS"
            case .iOS: return "iOS"
            case .macOSLobApp: return "macOS Line-of-Business"
            case .iosLobApp: return "iOS Line-of-Business"
            case .iosVppApp: return "iOS VPP"
            case .macOSVppApp: return "macOS VPP"
            case .managedIOSStoreApp: return "Managed iOS Store"
            case .managedMacOSStoreApp: return "Managed macOS Store"
            case .macOSOfficeSuiteApp: return "macOS Office Suite"
            case .webApp: return "Web App"
            case .macOSPkgApp: return "macOS PKG"
            case .macOSDmgApp: return "macOS DMG"
            case .iosStoreApp: return "iOS Store"
            case .androidStoreApp: return "Android Store"
            case .androidManagedStoreApp: return "Android Managed Store"
            case .windowsMobileMSI: return "Windows Mobile MSI"
            case .winAppX: return "Windows AppX"
            case .win32LobApp: return "Windows Win32"
            case .microsoftEdgeApp: return "Microsoft Edge"
            case .microsoftStoreForBusinessApp: return "Microsoft Store app (new)"
            case .windowsUniversalAppX: return "Windows Universal App"
            case .winGetApp: return "Windows Package Manager"
            case .officeSuiteApp: return "Microsoft 365 Apps"
            case .windowsWebApp: return "Windows Web App"
            case .win32CatalogApp: return "Windows catalog app (Win32)"
            case .microsoftDefenderForEndpoint: return "Microsoft Defender for Endpoint"
            case .macOSMicrosoftDefenderApp: return "macOS Microsoft Defender"
            case .unknown: return "Unknown"
            }
        }

        var icon: String {
            switch self {
            case .macOS, .macOSLobApp, .macOSVppApp, .managedMacOSStoreApp, .macOSOfficeSuiteApp, .macOSPkgApp, .macOSDmgApp:
                return "desktopcomputer"
            case .iOS, .iosLobApp, .iosVppApp, .managedIOSStoreApp, .iosStoreApp:
                return "iphone"
            case .webApp:
                return "globe"
            case .androidStoreApp, .androidManagedStoreApp:
                return "phone"
            case .windowsMobileMSI, .winAppX, .win32LobApp, .microsoftStoreForBusinessApp, .windowsUniversalAppX, .winGetApp, .win32CatalogApp:
                return "pc"
            case .microsoftEdgeApp, .windowsWebApp:
                return "network"
            case .officeSuiteApp:
                return "briefcase"
            case .microsoftDefenderForEndpoint, .macOSMicrosoftDefenderApp:
                return "shield"
            case .unknown:
                return "questionmark.app"
            }
        }

        init(odataType: String) {
            let sanitized = AppType.sanitizedType(from: odataType)

            Logger.shared.debug("Processing app type: '\(odataType)' -> sanitized: '\(sanitized)'", category: .data)

            // Try direct mapping first
            if let value = AppType(rawValue: sanitized) {
                self = value
                return
            }

            // Handle special cases and variations
            switch sanitized {
            case "macOSApp", "macOSApplication", "macOsApp", "macOsApplication":
                self = .macOS
            case "iosApp", "iosApplication":
                self = .iOS
            case "iosStoreApp":
                self = .iosStoreApp
            case "iosVppApp":
                self = .iosVppApp
            case "macOSVppApp", "macOsVppApp":
                self = .macOSVppApp
            case "managedIOSStoreApp":
                self = .managedIOSStoreApp
            case "managedMacOSStoreApp", "managedMacOsStoreApp":
                self = .managedMacOSStoreApp
            case "macOSLobApp", "macOsLobApp":
                self = .macOSLobApp
            case "iosLobApp":
                self = .iosLobApp
            case "microsoftStoreForBusinessApp":
                self = .microsoftStoreForBusinessApp
            case "windowsUniversalAppX":
                self = .windowsUniversalAppX
            case "winGetApp":
                self = .winGetApp
            case "officeSuiteApp":
                self = .officeSuiteApp
            case "windowsWebApp":
                self = .windowsWebApp
            case "webApp":
                self = .webApp
            case "win32CatalogApp":
                self = .win32CatalogApp
            case "microsoftDefenderForEndpointOnboardingPackageWindows10":
                self = .microsoftDefenderForEndpoint
            case "macOSMicrosoftDefenderApp":
                self = .macOSMicrosoftDefenderApp
            case "win32LobApp":
                self = .win32LobApp
            case "windowsMobileMSI":
                self = .windowsMobileMSI
            case "winAppX":
                self = .winAppX
            case "microsoftEdgeApp":
                self = .microsoftEdgeApp
            case "androidStoreApp":
                self = .androidStoreApp
            case "androidManagedStoreApp":
                self = .androidManagedStoreApp
            case "macOSOfficeSuiteApp", "macOsOfficeSuiteApp":
                self = .macOSOfficeSuiteApp
            case "macOSPkgApp", "macOsPkgApp":
                self = .macOSPkgApp
            case "macOSDmgApp", "macOsDmgApp":
                self = .macOSDmgApp
            default:
                Logger.shared.warning("Unknown application type encountered: '\(odataType)' (sanitized: '\(sanitized)'). Using 'unknown'.", category: .data)
                self = .unknown
            }
        }

        var odataType: String {
            switch self {
            case .macOS:
                return "#microsoft.graph.macOSApp"
            case .iOS:
                return "#microsoft.graph.iosStoreApp"
            default:
                return "#microsoft.graph.\(rawValue)"
            }
        }

        private static func sanitizedType(from odataType: String) -> String {
            let trimmed = odataType.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            if let lastComponent = trimmed.split(separator: ".").last {
                return String(lastComponent)
            }
            return trimmed
        }

        // MARK: - Platform Categorization

        /// Returns the primary platform category for this app type
        var platformCategory: DevicePlatform {
            switch self {
            case .macOS, .macOSLobApp, .macOSVppApp, .managedMacOSStoreApp,
                 .macOSOfficeSuiteApp, .macOSPkgApp, .macOSDmgApp, .macOSMicrosoftDefenderApp:
                return .macOS
            case .iOS, .iosLobApp, .iosVppApp, .managedIOSStoreApp, .iosStoreApp:
                return .iOS
            case .androidStoreApp, .androidManagedStoreApp:
                return .android
            case .windowsMobileMSI, .winAppX, .win32LobApp, .microsoftEdgeApp,
                 .microsoftStoreForBusinessApp, .windowsUniversalAppX, .winGetApp,
                 .officeSuiteApp, .windowsWebApp, .win32CatalogApp, .microsoftDefenderForEndpoint:
                return .windows
            case .webApp:
                return .unknown // Web apps are cross-platform
            case .unknown:
                return .unknown
            }
        }

        /// Returns all app types filtered by platform
        static func types(for platform: DevicePlatform?) -> [AppType] {
            guard let platform = platform else {
                return allCases.filter { $0 != .unknown }
            }

            return allCases.filter { type in
                type.platformCategory == platform && type != .unknown
            }
        }

        /// Returns app types grouped by platform for display in menus
        static var groupedByPlatform: [(platform: DevicePlatform, types: [AppType])] {
            let platforms: [DevicePlatform] = [.macOS, .iOS, .android, .windows]
            return platforms.map { platform in
                (platform: platform, types: types(for: platform))
            }
        }
    }

    struct MinimumOS: Codable, Sendable {
        var iOS: String?
        var macOS: String?
    }

    struct ApplicableDeviceType: Codable, Sendable {
        var iPad: Bool
        var iPhoneAndIPod: Bool
        var mac: Bool

        init(iPad: Bool = false, iPhoneAndIPod: Bool = false, mac: Bool = false) {
            self.iPad = iPad
            self.iPhoneAndIPod = iPhoneAndIPod
            self.mac = mac
        }

        enum CodingKeys: String, CodingKey {
            case iPad
            case iPhoneAndIPod
            case mac
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            iPad = try container.decodeIfPresent(Bool.self, forKey: .iPad) ?? false
            iPhoneAndIPod = try container.decodeIfPresent(Bool.self, forKey: .iPhoneAndIPod) ?? false
            mac = try container.decodeIfPresent(Bool.self, forKey: .mac) ?? false
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(iPad, forKey: .iPad)
            try container.encode(iPhoneAndIPod, forKey: .iPhoneAndIPod)
            try container.encode(mac, forKey: .mac)
        }
    }

    struct InstallSummary: Codable, Sendable {
        var installedDeviceCount: Int
        var failedDeviceCount: Int
        var notApplicableDeviceCount: Int
        var notInstalledDeviceCount: Int
        var pendingInstallDeviceCount: Int
        var installedUserCount: Int
        var failedUserCount: Int
        var notApplicableUserCount: Int
        var notInstalledUserCount: Int
        var pendingInstallUserCount: Int

        init() {
            self.installedDeviceCount = 0
            self.failedDeviceCount = 0
            self.notApplicableDeviceCount = 0
            self.notInstalledDeviceCount = 0
            self.pendingInstallDeviceCount = 0
            self.installedUserCount = 0
            self.failedUserCount = 0
            self.notApplicableUserCount = 0
            self.notInstalledUserCount = 0
            self.pendingInstallUserCount = 0
        }
    }

    init(id: String,
         displayName: String,
         appType: AppType,
         createdDateTime: Date = Date(),
         lastModifiedDateTime: Date = Date(),
         publishingState: PublishingState = .notPublished,
         isFeatured: Bool = false,
         ignoreVersionDetection: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.appType = appType
        self.createdDateTime = createdDateTime
        self.lastModifiedDateTime = lastModifiedDateTime
        self.publishingState = publishingState
        self.isFeatured = isFeatured
        self.ignoreVersionDetection = ignoreVersionDetection
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case description
        case publisher
        case largeIcon
        case createdDateTime
        case lastModifiedDateTime
        case isFeatured
        case privacyInformationUrl
        case informationUrl
        case owner
        case developer
        case notes
        case publishingState
        case rawAppType = "@odata.type"
        case version
        case fileName
        case size
        case minimumSupportedOperatingSystem
        case bundleId
        case appStoreUrl
        case applicableDeviceType
        case installCommandLine
        case uninstallCommandLine
        case ignoreVersionDetection
        case assignments
        case installSummary
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        appDescription = try container.decodeIfPresent(String.self, forKey: .description)
        publisher = try container.decodeIfPresent(String.self, forKey: .publisher)
        largeIcon = try container.decodeIfPresent(MimeContent.self, forKey: .largeIcon)
        createdDateTime = try container.decode(Date.self, forKey: .createdDateTime)
        lastModifiedDateTime = try container.decode(Date.self, forKey: .lastModifiedDateTime)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
        privacyInformationUrl = try container.decodeIfPresent(String.self, forKey: .privacyInformationUrl)
        informationUrl = try container.decodeIfPresent(String.self, forKey: .informationUrl)
        owner = try container.decodeIfPresent(String.self, forKey: .owner)
        developer = try container.decodeIfPresent(String.self, forKey: .developer)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        publishingState = try container.decodeIfPresent(PublishingState.self, forKey: .publishingState) ?? .notPublished

        if let rawType = try container.decodeIfPresent(String.self, forKey: .rawAppType) {
            appType = AppType(odataType: rawType)
        } else {
            Logger.shared.warning("No @odata.type found for application. Using 'unknown'.", category: .data)
            appType = .unknown
        }
        version = try container.decodeIfPresent(String.self, forKey: .version)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
        size = try container.decodeIfPresent(Int64.self, forKey: .size)
        minimumSupportedOperatingSystem = try container.decodeIfPresent(MinimumOS.self, forKey: .minimumSupportedOperatingSystem)
        bundleId = try container.decodeIfPresent(String.self, forKey: .bundleId)
        appStoreUrl = try container.decodeIfPresent(String.self, forKey: .appStoreUrl)
        applicableDeviceType = try container.decodeIfPresent(ApplicableDeviceType.self, forKey: .applicableDeviceType)
        installCommandLine = try container.decodeIfPresent(String.self, forKey: .installCommandLine)
        uninstallCommandLine = try container.decodeIfPresent(String.self, forKey: .uninstallCommandLine)
        ignoreVersionDetection = try container.decodeIfPresent(Bool.self, forKey: .ignoreVersionDetection) ?? false
        assignments = try container.decodeIfPresent([AppAssignment].self, forKey: .assignments)
        installSummary = try container.decodeIfPresent(InstallSummary.self, forKey: .installSummary)
    }

    // MARK: - Hashable

    static func == (lhs: Application, rhs: Application) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(appDescription, forKey: .description)
        try container.encodeIfPresent(publisher, forKey: .publisher)
        try container.encodeIfPresent(largeIcon, forKey: .largeIcon)
        try container.encode(createdDateTime, forKey: .createdDateTime)
        try container.encode(lastModifiedDateTime, forKey: .lastModifiedDateTime)
        try container.encode(isFeatured, forKey: .isFeatured)
        try container.encodeIfPresent(privacyInformationUrl, forKey: .privacyInformationUrl)
        try container.encodeIfPresent(informationUrl, forKey: .informationUrl)
        try container.encodeIfPresent(owner, forKey: .owner)
        try container.encodeIfPresent(developer, forKey: .developer)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(publishingState, forKey: .publishingState)
        try container.encode(appType.odataType, forKey: .rawAppType)
        try container.encodeIfPresent(version, forKey: .version)
        try container.encodeIfPresent(fileName, forKey: .fileName)
        try container.encodeIfPresent(size, forKey: .size)
        try container.encodeIfPresent(minimumSupportedOperatingSystem, forKey: .minimumSupportedOperatingSystem)
        try container.encodeIfPresent(bundleId, forKey: .bundleId)
        try container.encodeIfPresent(appStoreUrl, forKey: .appStoreUrl)
        try container.encodeIfPresent(applicableDeviceType, forKey: .applicableDeviceType)
        try container.encodeIfPresent(installCommandLine, forKey: .installCommandLine)
        try container.encodeIfPresent(uninstallCommandLine, forKey: .uninstallCommandLine)
        try container.encode(ignoreVersionDetection, forKey: .ignoreVersionDetection)
        try container.encodeIfPresent(assignments, forKey: .assignments)
        try container.encodeIfPresent(installSummary, forKey: .installSummary)
    }

    // MARK: - Computed Properties for Assignment Info

    var assignmentCount: Int {
        assignments?.count ?? 0
    }

    var hasAssignments: Bool {
        assignmentCount > 0
    }

    var isAssigned: Bool {
        hasAssignments
    }

    var assignmentSummary: String {
        guard let assignments = assignments, !assignments.isEmpty else {
            return "No assignments"
        }

        let groupCount = assignments.filter { assignment in
            assignment.target.type == .group || assignment.target.type == .exclusionGroup
        }.count

        let allUsersCount = assignments.filter { $0.target.type == .allUsers || $0.target.type == .allLicensedUsers }.count
        let allDevicesCount = assignments.filter { $0.target.type == .allDevices }.count

        var parts: [String] = []
        if groupCount > 0 {
            parts.append("\(groupCount) group\(groupCount == 1 ? "" : "s")")
        }
        if allUsersCount > 0 {
            parts.append("All users")
        }
        if allDevicesCount > 0 {
            parts.append("All devices")
        }

        return parts.joined(separator: ", ")
    }

    var primaryAssignmentIntent: AppAssignment.AssignmentIntent? {
        // Return the most restrictive intent (required > available)
        if assignments?.contains(where: { $0.intent == .required }) == true {
            return .required
        } else if assignments?.contains(where: { $0.intent == .available }) == true {
            return .available
        }
        return nil
    }
}

// MARK: - App Assignment
struct MimeContent: Codable, Sendable {
    let type: String?
    let value: String? // Base64 encoded string

    var decodedData: Data? {
        guard let value = value else { return nil }
        return Data(base64Encoded: value)
    }
}

struct AppAssignment: Codable, Identifiable, Sendable {
    let id: String
    let intent: AssignmentIntent
    let target: AssignmentTarget
    let settings: AssignmentSettings?
    let source: String?
    let sourceId: String?

    enum AssignmentIntent: String, Codable, CaseIterable, Sendable {
        case available
        case required
        case uninstall
        case availableWithoutEnrollment

        var displayName: String {
            switch self {
            case .available: return "Available"
            case .required: return "Required"
            case .uninstall: return "Uninstall"
            case .availableWithoutEnrollment: return "Available without enrollment"
            }
        }

        var icon: String {
            switch self {
            case .available: return "arrow.down.circle"
            case .required: return "exclamationmark.circle.fill"
            case .uninstall: return "trash.circle"
            case .availableWithoutEnrollment: return "arrow.down.circle.dotted"
            }
        }

        var detailedDescription: String {
            switch self {
            case .required:
                return "App will be automatically installed and cannot be uninstalled by users. Required for compliance."
            case .available:
                return "App is available in Company Portal for users to install when needed. Users can install and uninstall."
            case .uninstall:
                return "App will be uninstalled from targeted devices if already installed."
            case .availableWithoutEnrollment:
                return "App is available without requiring device enrollment in MDM. Useful for personal devices."
            }
        }
    }

    struct AssignmentTarget: Codable, Sendable {
        let type: TargetType
        let groupId: String?
        let groupName: String?
        let deviceAndAppManagementAssignmentFilterId: String?
        let deviceAndAppManagementAssignmentFilterType: String?

        enum CodingKeys: String, CodingKey {
            case type = "@odata.type"
            case groupId
            case groupName
            case deviceAndAppManagementAssignmentFilterId
            case deviceAndAppManagementAssignmentFilterType
        }

        enum TargetType: String, Codable, Sendable {
            case allUsers = "#microsoft.graph.allUsersAssignmentTarget"
            case allLicensedUsers = "#microsoft.graph.allLicensedUsersAssignmentTarget"
            case allDevices = "#microsoft.graph.allDevicesAssignmentTarget"
            case group = "#microsoft.graph.groupAssignmentTarget"
            case exclusionGroup = "#microsoft.graph.exclusionGroupAssignmentTarget"
            case configurationManagerCollection = "#microsoft.graph.configurationManagerCollectionAssignmentTarget"

            var displayName: String {
                switch self {
                case .allUsers:
                    return "All Users"
                case .allLicensedUsers:
                    return "All Licensed Users"
                case .allDevices:
                    return "All Devices"
                case .group:
                    return "Group"
                case .exclusionGroup:
                    return "Exclusion Group"
                case .configurationManagerCollection:
                    return "Configuration Manager Collection"
                }
            }

            var requiresGroupId: Bool {
                switch self {
                case .group, .exclusionGroup, .configurationManagerCollection:
                    return true
                case .allUsers, .allLicensedUsers, .allDevices:
                    return false
                }
            }
        }
    }

    struct AssignmentSettings: Codable, Sendable {
        let notificationsEnabled: Bool?
        let restartSettings: RestartSettings?
        let installTimeSettings: InstallTimeSettings?
        let deliveryOptimizationSettings: DeliveryOptimizationSettings?

        struct RestartSettings: Codable, Sendable {
            let gracePeriodInMinutes: Int?
            let countdownDisplayBeforeRestartInMinutes: Int?
            let restartNotificationSnoozeDurationInMinutes: Int?
        }

        struct InstallTimeSettings: Codable, Sendable {
            let useLocalTime: Bool?
            let startDateTime: Date?
            let deadlineDateTime: Date?
        }

        struct DeliveryOptimizationSettings: Codable, Sendable {
            let downloadMode: String?
            let groupIdSource: String?
            let bandwidthMode: String?
        }
    }
}
