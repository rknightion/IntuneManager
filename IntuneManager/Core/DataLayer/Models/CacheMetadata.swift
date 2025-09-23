import Foundation
import SwiftData

@Model
final class CacheMetadata: Identifiable {
    @Attribute(.unique)
    var id: String
    var entityType: String
    var lastFetch: Date
    var expiresAt: Date
    var recordCount: Int
    var isStale: Bool
    var eTag: String?
    var lastModified: Date?

    init(entityType: String,
         ttlSeconds: TimeInterval = 3600,
         recordCount: Int = 0,
         eTag: String? = nil) {
        self.id = entityType
        self.entityType = entityType
        self.lastFetch = Date()
        self.expiresAt = Date().addingTimeInterval(ttlSeconds)
        self.recordCount = recordCount
        self.isStale = false
        self.eTag = eTag
        self.lastModified = Date()
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var age: TimeInterval {
        Date().timeIntervalSince(lastFetch)
    }

    var remainingTTL: TimeInterval {
        max(0, expiresAt.timeIntervalSinceNow)
    }

    func markStale() {
        isStale = true
    }

    func refresh(ttlSeconds: TimeInterval, recordCount: Int) {
        self.lastFetch = Date()
        self.expiresAt = Date().addingTimeInterval(ttlSeconds)
        self.recordCount = recordCount
        self.isStale = false
        self.lastModified = Date()
    }
}

enum CachePolicy: String, CaseIterable {
    case devices = "Devices"
    case applications = "Applications"
    case groups = "Groups"
    case assignments = "Assignments"
    case compliancePolicies = "CompliancePolicies"
    case configurationProfiles = "ConfigurationProfiles"
    case auditLogs = "AuditLogs"
    case userProfiles = "UserProfiles"

    var ttlSeconds: TimeInterval {
        switch self {
        case .devices:
            return 300 // 5 minutes - frequently changing
        case .applications:
            return 1800 // 30 minutes - moderate updates
        case .groups:
            return 3600 // 1 hour - stable
        case .assignments:
            return 600 // 10 minutes - can change frequently
        case .compliancePolicies:
            return 86400 // 24 hours - rarely changes
        case .configurationProfiles:
            return 86400 // 24 hours - rarely changes
        case .auditLogs:
            return 60 // 1 minute - real-time data
        case .userProfiles:
            return 604800 // 7 days - very stable
        }
    }

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .devices:
            return "iphone"
        case .applications:
            return "app.badge"
        case .groups:
            return "person.3"
        case .assignments:
            return "arrow.right.square"
        case .compliancePolicies:
            return "checkmark.shield"
        case .configurationProfiles:
            return "gearshape"
        case .auditLogs:
            return "doc.text.magnifyingglass"
        case .userProfiles:
            return "person.circle"
        }
    }

    var priority: Int {
        switch self {
        case .devices: return 1
        case .applications: return 2
        case .assignments: return 3
        case .groups: return 4
        case .auditLogs: return 5
        case .compliancePolicies: return 6
        case .configurationProfiles: return 7
        case .userProfiles: return 8
        }
    }
}