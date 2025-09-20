import Foundation
import SwiftData

@Model
final class DeviceGroup: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var displayName: String
    var groupDescription: String?
    var createdDateTime: Date?
    var groupTypes: [String]?
    var membershipRule: String?
    var membershipRuleProcessingState: MembershipRuleProcessingState?
    var securityEnabled: Bool
    var mailEnabled: Bool
    var mailNickname: String?
    var onPremisesSyncEnabled: Bool?
    var proxyAddresses: [String]?
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
    var assignedApplications: [Application]?
    var members: [GroupMember]?

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
            case .on: return "green"
            case .paused: return "orange"
            case .evaluating: return "blue"
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
        groupTypes = try container.decodeIfPresent([String].self, forKey: .groupTypes)
        membershipRule = try container.decodeIfPresent(String.self, forKey: .membershipRule)
        membershipRuleProcessingState = try container.decodeIfPresent(MembershipRuleProcessingState.self, forKey: .membershipRuleProcessingState)
        securityEnabled = try container.decodeIfPresent(Bool.self, forKey: .securityEnabled) ?? false
        mailEnabled = try container.decodeIfPresent(Bool.self, forKey: .mailEnabled) ?? false
        mailNickname = try container.decodeIfPresent(String.self, forKey: .mailNickname)
        onPremisesSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .onPremisesSyncEnabled)
        proxyAddresses = try container.decodeIfPresent([String].self, forKey: .proxyAddresses)
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

// MARK: - Group Member
struct GroupMember: Codable, Identifiable {
    let id: String
    let displayName: String?
    let userPrincipalName: String?
    let mail: String?
    let memberType: MemberType

    enum MemberType: String, Codable {
        case user = "#microsoft.graph.user"
        case device = "#microsoft.graph.device"
        case group = "#microsoft.graph.group"
        case servicePrincipal = "#microsoft.graph.servicePrincipal"

        var icon: String {
            switch self {
            case .user: return "person"
            case .device: return "desktopcomputer"
            case .group: return "person.3"
            case .servicePrincipal: return "gearshape.2"
            }
        }
    }
}