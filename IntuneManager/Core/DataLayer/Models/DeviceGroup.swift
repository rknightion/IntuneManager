import Foundation
import SwiftData

@Model
final class DeviceGroup: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var displayName: String
    var groupDescription: String?
    var createdDateTime: Date?
    var groupTypesData: Data?
    var membershipRule: String?
    var membershipRuleProcessingState: MembershipRuleProcessingState?
    var securityEnabled: Bool
    var mailEnabled: Bool
    var mailNickname: String?
    var onPremisesSyncEnabled: Bool?
    var proxyAddressesData: Data?
    var visibility: String?
    var allowExternalSenders: Bool?
    var autoSubscribeNewMembers: Bool?
    var isSubscribedByMail: Bool?
    var unseenCount: Int?

    // Group statistics
    var memberCount: Int?
    var deviceCount: Int?
    var userCount: Int?

    // Relationships
    @Transient var assignedApplications: [Application]?
    @Transient var members: [GroupMember]?
    @Transient var owners: [GroupOwner]?

    enum MembershipRuleProcessingState: String, Codable {
        case on = "On"
        case paused = "Paused"
        case evaluating = "Evaluating"

        var displayName: String {
            switch self {
            case .on: return "Active"
            case .paused: return "Paused"
            case .evaluating: return "Processing"
            }
        }

        var displayColor: String {
            switch self {
            case .on: return "systemGreen"
            case .paused: return "systemOrange"
            case .evaluating: return "systemBlue"
            }
        }
    }

    enum GroupType: String, CaseIterable {
        case security = "Security"
        case office365 = "Office365"
        case dynamicMembership = "DynamicMembership"
        case unified = "Unified"

        var icon: String {
            switch self {
            case .security: return "lock.shield"
            case .office365: return "envelope"
            case .dynamicMembership: return "arrow.triangle.2.circlepath"
            case .unified: return "person.3"
            }
        }
    }

    init(id: String,
         displayName: String,
         securityEnabled: Bool = true,
         mailEnabled: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.securityEnabled = securityEnabled
        self.mailEnabled = mailEnabled
    }

    // Computed properties for array access
    var groupTypes: [String]? {
        get {
            guard let data = groupTypesData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            groupTypesData = try? JSONEncoder().encode(newValue)
        }
    }

    var proxyAddresses: [String]? {
        get {
            guard let data = proxyAddressesData else { return nil }
            return try? JSONDecoder().decode([String].self, from: data)
        }
        set {
            proxyAddressesData = try? JSONEncoder().encode(newValue)
        }
    }

    var isDynamicGroup: Bool {
        return membershipRule != nil && !membershipRule!.isEmpty
    }

    var groupTypeDisplay: String {
        var types: [String] = []

        if securityEnabled {
            types.append(GroupType.security.rawValue)
        }
        if mailEnabled {
            types.append(GroupType.office365.rawValue)
        }
        if isDynamicGroup {
            types.append(GroupType.dynamicMembership.rawValue)
        }
        if groupTypes?.contains("Unified") == true {
            types.append(GroupType.unified.rawValue)
        }

        return types.isEmpty ? "Standard" : types.joined(separator: ", ")
    }

    var primaryOwnerName: String? {
        return owners?.first?.displayName
    }

    var hasOwners: Bool {
        return owners != nil && !(owners?.isEmpty ?? true)
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case description
        case createdDateTime
        case groupTypes
        case membershipRule
        case membershipRuleProcessingState
        case securityEnabled
        case mailEnabled
        case mailNickname
        case onPremisesSyncEnabled
        case proxyAddresses
        case visibility
        case allowExternalSenders
        case autoSubscribeNewMembers
        case isSubscribedByMail
        case unseenCount
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        groupDescription = try container.decodeIfPresent(String.self, forKey: .description)
        createdDateTime = try container.decodeIfPresent(Date.self, forKey: .createdDateTime)

        // Decode arrays and convert to Data for storage
        if let types = try container.decodeIfPresent([String].self, forKey: .groupTypes) {
            groupTypesData = try? JSONEncoder().encode(types)
        }

        membershipRule = try container.decodeIfPresent(String.self, forKey: .membershipRule)
        membershipRuleProcessingState = try container.decodeIfPresent(MembershipRuleProcessingState.self, forKey: .membershipRuleProcessingState)
        securityEnabled = try container.decodeIfPresent(Bool.self, forKey: .securityEnabled) ?? false
        mailEnabled = try container.decodeIfPresent(Bool.self, forKey: .mailEnabled) ?? false
        mailNickname = try container.decodeIfPresent(String.self, forKey: .mailNickname)
        onPremisesSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .onPremisesSyncEnabled)

        // Decode arrays and convert to Data for storage
        if let addresses = try container.decodeIfPresent([String].self, forKey: .proxyAddresses) {
            proxyAddressesData = try? JSONEncoder().encode(addresses)
        }

        visibility = try container.decodeIfPresent(String.self, forKey: .visibility)
        allowExternalSenders = try container.decodeIfPresent(Bool.self, forKey: .allowExternalSenders)
        autoSubscribeNewMembers = try container.decodeIfPresent(Bool.self, forKey: .autoSubscribeNewMembers)
        isSubscribedByMail = try container.decodeIfPresent(Bool.self, forKey: .isSubscribedByMail)
        unseenCount = try container.decodeIfPresent(Int.self, forKey: .unseenCount)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(groupDescription, forKey: .description)
        try container.encodeIfPresent(createdDateTime, forKey: .createdDateTime)
        try container.encodeIfPresent(groupTypes, forKey: .groupTypes)
        try container.encodeIfPresent(membershipRule, forKey: .membershipRule)
        try container.encodeIfPresent(membershipRuleProcessingState, forKey: .membershipRuleProcessingState)
        try container.encode(securityEnabled, forKey: .securityEnabled)
        try container.encode(mailEnabled, forKey: .mailEnabled)
        try container.encodeIfPresent(mailNickname, forKey: .mailNickname)
        try container.encodeIfPresent(onPremisesSyncEnabled, forKey: .onPremisesSyncEnabled)
        try container.encodeIfPresent(proxyAddresses, forKey: .proxyAddresses)
        try container.encodeIfPresent(visibility, forKey: .visibility)
        try container.encodeIfPresent(allowExternalSenders, forKey: .allowExternalSenders)
        try container.encodeIfPresent(autoSubscribeNewMembers, forKey: .autoSubscribeNewMembers)
        try container.encodeIfPresent(isSubscribedByMail, forKey: .isSubscribedByMail)
        try container.encodeIfPresent(unseenCount, forKey: .unseenCount)
    }
}

// MARK: - Intune Built-In Targets
extension DeviceGroup {
    static let allDevicesGroupID = "intune-all-devices"
    static let allUsersGroupID = "intune-all-users"

    static var builtInAssignmentTargets: [DeviceGroup] {
        Self.builtInTargetsStorage
    }

    var isBuiltInAssignmentTarget: Bool {
        id == DeviceGroup.allDevicesGroupID || id == DeviceGroup.allUsersGroupID
    }

    var assignmentTargetType: AppAssignment.AssignmentTarget.TargetType {
        switch id {
        case DeviceGroup.allDevicesGroupID:
            return .allDevices
        case DeviceGroup.allUsersGroupID:
            return .allUsers
        default:
            return .group
        }
    }

    private static let builtInTargetsStorage: [DeviceGroup] = {
        let allDevices = DeviceGroup(
            id: DeviceGroup.allDevicesGroupID,
            displayName: "All Devices",
            securityEnabled: true,
            mailEnabled: false
        )
        allDevices.groupDescription = "Assigns to every managed device in the tenant."
        allDevices.deviceCount = nil
        allDevices.userCount = nil

        let allUsers = DeviceGroup(
            id: DeviceGroup.allUsersGroupID,
            displayName: "All Users",
            securityEnabled: true,
            mailEnabled: false
        )
        allUsers.groupDescription = "Assigns to every licensed user in the tenant."
        allUsers.deviceCount = nil
        allUsers.userCount = nil

        return [allDevices, allUsers]
    }()
}

// MARK: - Group Member
struct GroupMember: Codable, Identifiable, Sendable {
    let id: String
    let displayName: String?
    let userPrincipalName: String?
    let mail: String?
    let memberType: MemberType

    // Device-specific fields
    let deviceId: String?
    let operatingSystem: String?
    let operatingSystemVersion: String?
    let accountEnabled: Bool?

    // Group-specific fields
    let groupTypes: [String]?
    let securityEnabled: Bool?

    enum MemberType: String, Codable, Sendable {
        case user = "#microsoft.graph.user"
        case device = "#microsoft.graph.device"
        case group = "#microsoft.graph.group"
        case servicePrincipal = "#microsoft.graph.servicePrincipal"
        case unknown = "unknown"

        var icon: String {
            switch self {
            case .user: return "person"
            case .device: return "desktopcomputer"
            case .group: return "person.3"
            case .servicePrincipal: return "gearshape.2"
            case .unknown: return "questionmark.circle"
            }
        }

        var displayName: String {
            switch self {
            case .user: return "User"
            case .device: return "Device"
            case .group: return "Group"
            case .servicePrincipal: return "Service Principal"
            case .unknown: return "Unknown"
            }
        }
    }

    // Computed property for unified display name
    var effectiveDisplayName: String {
        if let name = displayName, !name.isEmpty {
            return name
        }
        // Fallback for devices without displayName
        if memberType == .device {
            if let deviceId = deviceId {
                return deviceId
            }
        }
        // Fallback for other types
        if let upn = userPrincipalName {
            return upn
        }
        if let mail = mail {
            return mail
        }
        return "Unknown"
    }

    // Computed property for secondary info
    var secondaryInfo: String? {
        switch memberType {
        case .device:
            if let os = operatingSystem, let version = operatingSystemVersion {
                return "\(os) \(version)"
            } else if let os = operatingSystem {
                return os
            }
            return deviceId
        case .user:
            return userPrincipalName ?? mail
        case .group:
            if let types = groupTypes, !types.isEmpty {
                return types.joined(separator: ", ")
            }
            return securityEnabled == true ? "Security Group" : "Group"
        case .servicePrincipal:
            return mail
        case .unknown:
            return nil
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case userPrincipalName
        case mail
        case memberType = "@odata.type"
        case deviceId
        case operatingSystem
        case operatingSystemVersion
        case accountEnabled
        case groupTypes
        case securityEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        userPrincipalName = try container.decodeIfPresent(String.self, forKey: .userPrincipalName)
        mail = try container.decodeIfPresent(String.self, forKey: .mail)

        // Device-specific fields
        deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        operatingSystem = try container.decodeIfPresent(String.self, forKey: .operatingSystem)
        operatingSystemVersion = try container.decodeIfPresent(String.self, forKey: .operatingSystemVersion)
        accountEnabled = try container.decodeIfPresent(Bool.self, forKey: .accountEnabled)

        // Group-specific fields
        groupTypes = try container.decodeIfPresent([String].self, forKey: .groupTypes)
        securityEnabled = try container.decodeIfPresent(Bool.self, forKey: .securityEnabled)

        // Decode memberType with fallback to unknown
        if let typeString = try container.decodeIfPresent(String.self, forKey: .memberType),
           let type = MemberType(rawValue: typeString) {
            memberType = type
        } else {
            memberType = .unknown
        }
    }
}

// MARK: - Group Owner
struct GroupOwner: Codable, Identifiable, Sendable {
    let id: String
    let displayName: String?
    let userPrincipalName: String?
    let mail: String?
    let ownerType: OwnerType

    enum OwnerType: String, Codable, Sendable {
        case user = "#microsoft.graph.user"
        case servicePrincipal = "#microsoft.graph.servicePrincipal"

        var icon: String {
            switch self {
            case .user: return "person.crop.circle"
            case .servicePrincipal: return "gearshape.2.fill"
            }
        }

        var displayName: String {
            switch self {
            case .user: return "User"
            case .servicePrincipal: return "Service Principal"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case userPrincipalName
        case mail
        case ownerType = "@odata.type"
    }
}
