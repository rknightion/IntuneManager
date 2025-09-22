import Foundation
import SwiftData

@Model
final class Application: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var displayName: String
    var appDescription: String?
    var publisher: String?
    var largeIcon: Data?
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
            }
        }

        var icon: String {
            switch self {
            case .macOS, .macOSLobApp, .macOSVppApp, .managedMacOSStoreApp, .macOSOfficeSuiteApp, .macOSPkgApp, .macOSDmgApp:
                return "desktopcomputer"
            case .iOS, .iosLobApp, .iosVppApp, .managedIOSStoreApp:
                return "iphone"
            case .webApp:
                return "globe"
            }
        }

        init?(odataType: String) {
            let sanitized = AppType.sanitizedType(from: odataType)

            switch sanitized {
            case "macOSApp":
                self = .macOS
            case "iosStoreApp":
                self = .iOS
            default:
                guard let value = AppType(rawValue: sanitized) else {
                    return nil
                }
                self = value
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
        largeIcon = try container.decodeIfPresent(Data.self, forKey: .largeIcon)
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
            if let resolvedType = AppType(odataType: rawType) {
                appType = resolvedType
            } else {
                Logger.shared.warning("Unknown application type encountered: \(rawType)")
                appType = .macOS
            }
        } else {
            appType = .macOS
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
}

// MARK: - App Assignment
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
