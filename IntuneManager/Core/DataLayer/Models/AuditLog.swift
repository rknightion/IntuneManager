import Foundation
import SwiftData

@Model
final class AuditLog: Codable {
    @Attribute(.unique) var id: String
    var displayName: String?
    var componentName: String?
    var activity: String?
    var activityDateTime: Date?
    var activityType: String?
    var activityOperationType: String?
    var activityResult: String?
    var correlationId: String?
    var category: String?

    @Relationship var actor: AuditActor?
    @Relationship(deleteRule: .cascade) var resources: [AuditResource]?

    // Not persisted - for transient display only
    @Transient var isExpanded: Bool = false

    init(
        id: String,
        displayName: String? = nil,
        componentName: String? = nil,
        activity: String? = nil,
        activityDateTime: Date? = nil,
        activityType: String? = nil,
        activityOperationType: String? = nil,
        activityResult: String? = nil,
        correlationId: String? = nil,
        category: String? = nil,
        actor: AuditActor? = nil,
        resources: [AuditResource]? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.componentName = componentName
        self.activity = activity
        self.activityDateTime = activityDateTime
        self.activityType = activityType
        self.activityOperationType = activityOperationType
        self.activityResult = activityResult
        self.correlationId = correlationId
        self.category = category
        self.actor = actor
        self.resources = resources
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case componentName
        case activity
        case activityDateTime
        case activityType
        case activityOperationType
        case activityResult
        case correlationId
        case category
        case actor
        case resources
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.componentName = try container.decodeIfPresent(String.self, forKey: .componentName)
        self.activity = try container.decodeIfPresent(String.self, forKey: .activity)
        self.activityDateTime = try container.decodeIfPresent(Date.self, forKey: .activityDateTime)
        self.activityType = try container.decodeIfPresent(String.self, forKey: .activityType)
        self.activityOperationType = try container.decodeIfPresent(String.self, forKey: .activityOperationType)
        self.activityResult = try container.decodeIfPresent(String.self, forKey: .activityResult)
        self.correlationId = try container.decodeIfPresent(String.self, forKey: .correlationId)
        self.category = try container.decodeIfPresent(String.self, forKey: .category)
        self.actor = try container.decodeIfPresent(AuditActor.self, forKey: .actor)
        self.resources = try container.decodeIfPresent([AuditResource].self, forKey: .resources)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(componentName, forKey: .componentName)
        try container.encodeIfPresent(activity, forKey: .activity)
        try container.encodeIfPresent(activityDateTime, forKey: .activityDateTime)
        try container.encodeIfPresent(activityType, forKey: .activityType)
        try container.encodeIfPresent(activityOperationType, forKey: .activityOperationType)
        try container.encodeIfPresent(activityResult, forKey: .activityResult)
        try container.encodeIfPresent(correlationId, forKey: .correlationId)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(actor, forKey: .actor)
        try container.encodeIfPresent(resources, forKey: .resources)
    }
}

@Model
final class AuditActor: Codable {
    var type: String?
    var auditActorType: String?
    var userPermissions: [String]?
    var applicationId: String?
    var applicationDisplayName: String?
    var userPrincipalName: String?
    var servicePrincipalName: String?
    var ipAddress: String?
    var userId: String?

    init(
        type: String? = nil,
        auditActorType: String? = nil,
        userPermissions: [String]? = nil,
        applicationId: String? = nil,
        applicationDisplayName: String? = nil,
        userPrincipalName: String? = nil,
        servicePrincipalName: String? = nil,
        ipAddress: String? = nil,
        userId: String? = nil
    ) {
        self.type = type
        self.auditActorType = auditActorType
        self.userPermissions = userPermissions
        self.applicationId = applicationId
        self.applicationDisplayName = applicationDisplayName
        self.userPrincipalName = userPrincipalName
        self.servicePrincipalName = servicePrincipalName
        self.ipAddress = ipAddress
        self.userId = userId
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case type
        case auditActorType
        case userPermissions
        case applicationId
        case applicationDisplayName
        case userPrincipalName
        case servicePrincipalName
        case ipAddress
        case userId
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.auditActorType = try container.decodeIfPresent(String.self, forKey: .auditActorType)
        self.userPermissions = try container.decodeIfPresent([String].self, forKey: .userPermissions)
        self.applicationId = try container.decodeIfPresent(String.self, forKey: .applicationId)
        self.applicationDisplayName = try container.decodeIfPresent(String.self, forKey: .applicationDisplayName)
        self.userPrincipalName = try container.decodeIfPresent(String.self, forKey: .userPrincipalName)
        self.servicePrincipalName = try container.decodeIfPresent(String.self, forKey: .servicePrincipalName)
        self.ipAddress = try container.decodeIfPresent(String.self, forKey: .ipAddress)
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(auditActorType, forKey: .auditActorType)
        try container.encodeIfPresent(userPermissions, forKey: .userPermissions)
        try container.encodeIfPresent(applicationId, forKey: .applicationId)
        try container.encodeIfPresent(applicationDisplayName, forKey: .applicationDisplayName)
        try container.encodeIfPresent(userPrincipalName, forKey: .userPrincipalName)
        try container.encodeIfPresent(servicePrincipalName, forKey: .servicePrincipalName)
        try container.encodeIfPresent(ipAddress, forKey: .ipAddress)
        try container.encodeIfPresent(userId, forKey: .userId)
    }

    var displayName: String {
        return userPrincipalName ?? applicationDisplayName ?? servicePrincipalName ?? "Unknown Actor"
    }
}

@Model
final class AuditResource: Codable {
    var displayName: String?
    var type: String?
    var auditResourceType: String?
    var resourceId: String?

    @Relationship(deleteRule: .cascade) var modifiedProperties: [AuditProperty]?

    init(
        displayName: String? = nil,
        type: String? = nil,
        auditResourceType: String? = nil,
        resourceId: String? = nil,
        modifiedProperties: [AuditProperty]? = nil
    ) {
        self.displayName = displayName
        self.type = type
        self.auditResourceType = auditResourceType
        self.resourceId = resourceId
        self.modifiedProperties = modifiedProperties
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case displayName
        case type
        case auditResourceType
        case resourceId
        case modifiedProperties
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.auditResourceType = try container.decodeIfPresent(String.self, forKey: .auditResourceType)
        self.resourceId = try container.decodeIfPresent(String.self, forKey: .resourceId)
        self.modifiedProperties = try container.decodeIfPresent([AuditProperty].self, forKey: .modifiedProperties)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(auditResourceType, forKey: .auditResourceType)
        try container.encodeIfPresent(resourceId, forKey: .resourceId)
        try container.encodeIfPresent(modifiedProperties, forKey: .modifiedProperties)
    }
}

@Model
final class AuditProperty: Codable {
    var displayName: String?
    var oldValue: String?
    var newValue: String?

    init(
        displayName: String? = nil,
        oldValue: String? = nil,
        newValue: String? = nil
    ) {
        self.displayName = displayName
        self.oldValue = oldValue
        self.newValue = newValue
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case displayName
        case oldValue
        case newValue
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.oldValue = try container.decodeIfPresent(String.self, forKey: .oldValue)
        self.newValue = try container.decodeIfPresent(String.self, forKey: .newValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(oldValue, forKey: .oldValue)
        try container.encodeIfPresent(newValue, forKey: .newValue)
    }
}