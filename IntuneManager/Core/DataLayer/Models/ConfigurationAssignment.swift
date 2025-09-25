import Foundation
import SwiftData

/// Represents an assignment of a configuration profile to a group
@Model
final class ConfigurationAssignment: Identifiable, Codable, Sendable {
    @Attribute(.unique) var id: String
    var profileId: String
    var target: AssignmentTarget
    var filter: AssignmentFilter?
    var createdDateTime: Date
    var lastModifiedDateTime: Date
    var source: String?
    var sourceId: String?

    /// Assignment target
    struct AssignmentTarget: Codable {
        let type: TargetType
        let groupId: String?
        let groupName: String?

        enum TargetType: String, Codable {
            case allDevices = "allDevices"
            case allUsers = "allUsers"
            case group = "group"
            case exclusionGroup = "exclusionGroup"
            case allLicensedUsers = "allLicensedUsers"
        }
    }

    /// Assignment filter
    struct AssignmentFilter: Codable {
        let filterId: String
        let filterType: FilterType

        enum FilterType: String, Codable {
            case include = "include"
            case exclude = "exclude"
        }
    }

    init(
        id: String = UUID().uuidString,
        profileId: String,
        target: AssignmentTarget,
        filter: AssignmentFilter? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.target = target
        self.filter = filter
        self.createdDateTime = Date()
        self.lastModifiedDateTime = Date()
        self.source = nil
        self.sourceId = nil
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case profileId
        case target
        case filter
        case createdDateTime
        case lastModifiedDateTime
        case source
        case sourceId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        profileId = try container.decode(String.self, forKey: .profileId)
        target = try container.decode(AssignmentTarget.self, forKey: .target)
        filter = try container.decodeIfPresent(AssignmentFilter.self, forKey: .filter)
        createdDateTime = try container.decodeIfPresent(Date.self, forKey: .createdDateTime) ?? Date()
        lastModifiedDateTime = try container.decodeIfPresent(Date.self, forKey: .lastModifiedDateTime) ?? Date()
        source = try container.decodeIfPresent(String.self, forKey: .source)
        sourceId = try container.decodeIfPresent(String.self, forKey: .sourceId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(profileId, forKey: .profileId)
        try container.encode(target, forKey: .target)
        try container.encodeIfPresent(filter, forKey: .filter)
        try container.encode(createdDateTime, forKey: .createdDateTime)
        try container.encode(lastModifiedDateTime, forKey: .lastModifiedDateTime)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(sourceId, forKey: .sourceId)
    }
}

// MARK: - Extensions

extension ConfigurationAssignment.AssignmentTarget {
    var displayName: String {
        switch type {
        case .allDevices:
            return "All Devices"
        case .allUsers:
            return "All Users"
        case .allLicensedUsers:
            return "All Licensed Users"
        case .group, .exclusionGroup:
            return groupName ?? "Unknown Group"
        }
    }
}

extension ConfigurationAssignment.AssignmentTarget.TargetType {
    var icon: String {
        switch self {
        case .allDevices:
            return "laptopcomputer"
        case .allUsers, .allLicensedUsers:
            return "person.2.fill"
        case .group:
            return "person.3.fill"
        case .exclusionGroup:
            return "person.3.slash"
        }
    }

    var displayName: String {
        switch self {
        case .allDevices:
            return "All Devices"
        case .allUsers:
            return "All Users"
        case .allLicensedUsers:
            return "All Licensed Users"
        case .group:
            return "Group"
        case .exclusionGroup:
            return "Exclusion Group"
        }
    }
}

// MARK: - Graph API Response Models

/// Assignment response from Graph API
struct ConfigurationAssignmentResponse: Codable {
    let value: [GraphConfigurationAssignment]
    let nextLink: String?

    enum CodingKeys: String, CodingKey {
        case value
        case nextLink = "@odata.nextLink"
    }
}

/// Individual assignment from Graph API
struct GraphConfigurationAssignment: Codable {
    let id: String
    let target: GraphAssignmentTarget
    let filter: GraphAssignmentFilter?
    let source: String?
    let sourceId: String?

    struct GraphAssignmentTarget: Codable {
        let odataType: String
        let groupId: String?

        enum CodingKeys: String, CodingKey {
            case odataType = "@odata.type"
            case groupId
        }
    }

    struct GraphAssignmentFilter: Codable {
        let deviceAndAppManagementAssignmentFilterId: String?
        let deviceAndAppManagementAssignmentFilterType: String?
    }

    /// Convert to our model
    func toConfigurationAssignment(profileId: String) -> ConfigurationAssignment {
        let targetType: ConfigurationAssignment.AssignmentTarget.TargetType
        switch target.odataType {
        case _ where target.odataType.contains("allDevicesAssignmentTarget"):
            targetType = .allDevices
        case _ where target.odataType.contains("allLicensedUsersAssignmentTarget"):
            targetType = .allLicensedUsers
        case _ where target.odataType.contains("exclusionGroupAssignmentTarget"):
            targetType = .exclusionGroup
        case _ where target.odataType.contains("groupAssignmentTarget"):
            targetType = .group
        default:
            targetType = .group
        }

        let assignmentTarget = ConfigurationAssignment.AssignmentTarget(
            type: targetType,
            groupId: target.groupId,
            groupName: nil
        )

        var assignmentFilter: ConfigurationAssignment.AssignmentFilter? = nil
        if let filterId = filter?.deviceAndAppManagementAssignmentFilterId,
           let filterTypeStr = filter?.deviceAndAppManagementAssignmentFilterType {
            let filterType: ConfigurationAssignment.AssignmentFilter.FilterType =
                filterTypeStr.lowercased().contains("exclude") ? .exclude : .include
            assignmentFilter = ConfigurationAssignment.AssignmentFilter(
                filterId: filterId,
                filterType: filterType
            )
        }

        return ConfigurationAssignment(
            id: id,
            profileId: profileId,
            target: assignmentTarget,
            filter: assignmentFilter
        )
    }
}