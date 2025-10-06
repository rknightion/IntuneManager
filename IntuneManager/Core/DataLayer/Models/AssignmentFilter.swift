import Foundation
import SwiftData

/// Represents a device and app management assignment filter from Microsoft Graph API
/// Endpoint: GET /deviceManagement/assignmentFilters
@Model
final class AssignmentFilter: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var displayName: String
    var filterDescription: String? // 'description' is a reserved word
    var platform: FilterPlatform
    var rule: String // The filter expression/query
    var createdDateTime: Date?
    var lastModifiedDateTime: Date?
    var roleScopeTags: [String]?
    var assignmentFilterManagementType: ManagementType?

    enum FilterPlatform: String, Codable, CaseIterable {
        case android = "android"
        case androidForWork = "androidForWork"
        case ios = "iOS"
        case macOS = "macOS"
        case windows10AndLater = "windows10AndLater"
        case windows81AndLater = "windows81AndLater"
        case unknownFutureValue = "unknownFutureValue"

        var displayName: String {
            switch self {
            case .android: return "Android"
            case .androidForWork: return "Android Enterprise"
            case .ios: return "iOS/iPadOS"
            case .macOS: return "macOS"
            case .windows10AndLater: return "Windows 10+"
            case .windows81AndLater: return "Windows 8.1+"
            case .unknownFutureValue: return "Unknown"
            }
        }

        var icon: String {
            switch self {
            case .android, .androidForWork: return "smartphone"
            case .ios: return "iphone"
            case .macOS: return "desktopcomputer"
            case .windows10AndLater, .windows81AndLater: return "pc"
            case .unknownFutureValue: return "questionmark.circle"
            }
        }
    }

    enum ManagementType: String, Codable {
        case devices = "devices"
        case apps = "apps"
        case unknownFutureValue = "unknownFutureValue"
    }

    init(id: String = UUID().uuidString,
         displayName: String,
         filterDescription: String? = nil,
         platform: FilterPlatform,
         rule: String,
         createdDateTime: Date? = nil,
         lastModifiedDateTime: Date? = nil,
         roleScopeTags: [String]? = nil,
         assignmentFilterManagementType: ManagementType? = nil) {
        self.id = id
        self.displayName = displayName
        self.filterDescription = filterDescription
        self.platform = platform
        self.rule = rule
        self.createdDateTime = createdDateTime
        self.lastModifiedDateTime = lastModifiedDateTime
        self.roleScopeTags = roleScopeTags
        self.assignmentFilterManagementType = assignmentFilterManagementType
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case filterDescription = "description"
        case platform
        case rule
        case createdDateTime
        case lastModifiedDateTime
        case roleScopeTags
        case assignmentFilterManagementType
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.filterDescription = try container.decodeIfPresent(String.self, forKey: .filterDescription)
        self.platform = try container.decode(FilterPlatform.self, forKey: .platform)
        self.rule = try container.decode(String.self, forKey: .rule)
        self.createdDateTime = try container.decodeIfPresent(Date.self, forKey: .createdDateTime)
        self.lastModifiedDateTime = try container.decodeIfPresent(Date.self, forKey: .lastModifiedDateTime)
        self.roleScopeTags = try container.decodeIfPresent([String].self, forKey: .roleScopeTags)
        self.assignmentFilterManagementType = try container.decodeIfPresent(ManagementType.self, forKey: .assignmentFilterManagementType)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(filterDescription, forKey: .filterDescription)
        try container.encode(platform, forKey: .platform)
        try container.encode(rule, forKey: .rule)
        try container.encodeIfPresent(createdDateTime, forKey: .createdDateTime)
        try container.encodeIfPresent(lastModifiedDateTime, forKey: .lastModifiedDateTime)
        try container.encodeIfPresent(roleScopeTags, forKey: .roleScopeTags)
        try container.encodeIfPresent(assignmentFilterManagementType, forKey: .assignmentFilterManagementType)
    }
}

// MARK: - Graph API Response

struct AssignmentFilterResponse: Codable {
    let value: [AssignmentFilter]
}
