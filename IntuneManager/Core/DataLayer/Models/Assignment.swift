import Foundation
import SwiftData

@Model
final class Assignment: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var applicationId: String
    var applicationName: String
    var groupId: String
    var groupName: String
    var targetType: AppAssignment.AssignmentTarget.TargetType
    var intent: AssignmentIntent
    var status: AssignmentStatus
    var createdDate: Date
    var modifiedDate: Date
    var completedDate: Date?
    var errorMessage: String?
    var errorCategory: String?  // Stores error category for remediation
    var failureTimestamp: Date?  // When the assignment last failed
    var retryCount: Int
    var batchId: String?
    var priority: AssignmentPriority

    // Additional metadata
    var settings: AssignmentSettings?
    var graphSettingsData: Data?  // Encoded AppAssignmentSettings for Graph API
    var filter: AssignmentFilter?

    // Computed property to access graphSettings
    var graphSettings: AppAssignmentSettings? {
        get {
            guard let data = graphSettingsData else { return nil }
            return try? JSONDecoder().decode(AppAssignmentSettings.self, from: data)
        }
        set {
            graphSettingsData = try? JSONEncoder().encode(newValue)
        }
    }
    var scheduledDate: Date?
    var createdBy: String?
    var modifiedBy: String?

    enum AssignmentIntent: String, Codable, CaseIterable {
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

        var color: String {
            switch self {
            case .available: return "blue"
            case .required: return "orange"
            case .uninstall: return "red"
            case .availableWithoutEnrollment: return "purple"
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

    enum AssignmentStatus: String, Codable, CaseIterable {
        case pending
        case inProgress
        case completed
        case failed
        case cancelled
        case scheduled
        case retrying

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .failed: return "Failed"
            case .cancelled: return "Cancelled"
            case .scheduled: return "Scheduled"
            case .retrying: return "Retrying"
            }
        }

        var icon: String {
            switch self {
            case .pending: return "clock"
            case .inProgress: return "arrow.triangle.circlepath"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            case .cancelled: return "xmark.octagon.fill"
            case .scheduled: return "calendar.circle"
            case .retrying: return "arrow.clockwise.circle"
            }
        }

        var color: String {
            switch self {
            case .pending: return "systemGray"
            case .inProgress: return "systemBlue"
            case .completed: return "systemGreen"
            case .failed: return "systemRed"
            case .cancelled: return "systemOrange"
            case .scheduled: return "systemPurple"
            case .retrying: return "systemYellow"
            }
        }
    }

    enum AssignmentPriority: Int, Codable, CaseIterable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        var displayName: String {
            switch self {
            case .low: return "Low"
            case .normal: return "Normal"
            case .high: return "High"
            case .critical: return "Critical"
            }
        }

        var icon: String {
            switch self {
            case .low: return "tortoise"
            case .normal: return "hare"
            case .high: return "flame"
            case .critical: return "exclamationmark.3"
            }
        }
    }

    struct AssignmentSettings: Codable {
        var notificationEnabled: Bool?
        var restartSettings: RestartSettings?
        var installTimeSettings: InstallTimeSettings?
        var uninstallOnDeviceRemoval: Bool?
        var vpnConfigurationId: String?

        struct RestartSettings: Codable {
            var gracePeriodInMinutes: Int?
            var countdownDisplayBeforeRestartInMinutes: Int?
            var restartNotificationSnoozeDurationInMinutes: Int?
        }

        struct InstallTimeSettings: Codable {
            var useLocalTime: Bool?
            var startDateTime: Date?
            var deadlineDateTime: Date?
        }
    }

    struct AssignmentFilter: Codable {
        var filterId: String?
        var filterType: FilterType?
        var filterExpression: String?

        enum FilterType: String, Codable {
            case include
            case exclude
        }
    }

    init(id: String = UUID().uuidString,
         applicationId: String,
         applicationName: String,
         groupId: String,
         groupName: String,
         targetType: AppAssignment.AssignmentTarget.TargetType = .group,
         intent: AssignmentIntent,
         status: AssignmentStatus = .pending,
         priority: AssignmentPriority = .normal) {
        self.id = id
        self.applicationId = applicationId
        self.applicationName = applicationName
        self.groupId = groupId
        self.groupName = groupName
        self.targetType = targetType
        self.intent = intent
        self.status = status
        self.priority = priority
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.retryCount = 0
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case applicationId
        case applicationName
        case groupId
        case groupName
        case targetType
        case intent
        case status
        case createdDate
        case modifiedDate
        case completedDate
        case errorMessage
        case errorCategory
        case failureTimestamp
        case retryCount
        case batchId
        case priority
        case settings
        case graphSettingsData
        case filter
        case scheduledDate
        case createdBy
        case modifiedBy
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        applicationId = try container.decode(String.self, forKey: .applicationId)
        applicationName = try container.decode(String.self, forKey: .applicationName)
        groupId = try container.decode(String.self, forKey: .groupId)
        groupName = try container.decode(String.self, forKey: .groupName)
        targetType = try container.decodeIfPresent(AppAssignment.AssignmentTarget.TargetType.self, forKey: .targetType) ?? .group
        intent = try container.decode(AssignmentIntent.self, forKey: .intent)
        status = try container.decode(AssignmentStatus.self, forKey: .status)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        modifiedDate = try container.decode(Date.self, forKey: .modifiedDate)
        completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        errorCategory = try container.decodeIfPresent(String.self, forKey: .errorCategory)
        failureTimestamp = try container.decodeIfPresent(Date.self, forKey: .failureTimestamp)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
        batchId = try container.decodeIfPresent(String.self, forKey: .batchId)
        priority = try container.decode(AssignmentPriority.self, forKey: .priority)
        settings = try container.decodeIfPresent(AssignmentSettings.self, forKey: .settings)
        graphSettingsData = try container.decodeIfPresent(Data.self, forKey: .graphSettingsData)
        filter = try container.decodeIfPresent(AssignmentFilter.self, forKey: .filter)
        scheduledDate = try container.decodeIfPresent(Date.self, forKey: .scheduledDate)
        createdBy = try container.decodeIfPresent(String.self, forKey: .createdBy)
        modifiedBy = try container.decodeIfPresent(String.self, forKey: .modifiedBy)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(applicationId, forKey: .applicationId)
        try container.encode(applicationName, forKey: .applicationName)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(groupName, forKey: .groupName)
        try container.encode(targetType, forKey: .targetType)
        try container.encode(intent, forKey: .intent)
        try container.encode(status, forKey: .status)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encode(modifiedDate, forKey: .modifiedDate)
        try container.encodeIfPresent(completedDate, forKey: .completedDate)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encodeIfPresent(errorCategory, forKey: .errorCategory)
        try container.encodeIfPresent(failureTimestamp, forKey: .failureTimestamp)
        try container.encode(retryCount, forKey: .retryCount)
        try container.encodeIfPresent(batchId, forKey: .batchId)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(graphSettingsData, forKey: .graphSettingsData)
        try container.encodeIfPresent(filter, forKey: .filter)
        try container.encodeIfPresent(scheduledDate, forKey: .scheduledDate)
        try container.encodeIfPresent(createdBy, forKey: .createdBy)
        try container.encodeIfPresent(modifiedBy, forKey: .modifiedBy)
    }
}

// MARK: - Bulk Assignment Operation
struct BulkAssignmentOperation: Identifiable {
    let id = UUID().uuidString
    let applications: [Application]
    let groups: [DeviceGroup]
    let intent: Assignment.AssignmentIntent
    let settings: Assignment.AssignmentSettings?
    let groupSettings: [GroupAssignmentSettings]?  // Per-group settings
    let scheduledDate: Date?
    var totalOperations: Int {
        applications.count * groups.count
    }

    init(applications: [Application],
         groups: [DeviceGroup],
         intent: Assignment.AssignmentIntent,
         settings: Assignment.AssignmentSettings? = nil,
         groupSettings: [GroupAssignmentSettings]? = nil,
         scheduledDate: Date? = nil) {
        self.applications = applications
        self.groups = groups
        self.intent = intent
        self.settings = settings
        self.groupSettings = groupSettings
        self.scheduledDate = scheduledDate
    }

    func createAssignments() -> [Assignment] {
        var assignments: [Assignment] = []

        for app in applications {
            for group in groups {
                // Use per-group settings intent if available, otherwise use global intent
                let assignmentIntent: Assignment.AssignmentIntent
                if let groupSetting = groupSettings?.first(where: { $0.groupId == group.id }) {
                    // Use the intent from the group-specific settings
                    assignmentIntent = groupSetting.settings.intent
                } else {
                    // Fall back to the global intent
                    assignmentIntent = intent
                }

                let assignment = Assignment(
                    applicationId: app.id,
                    applicationName: app.displayName,
                    groupId: group.id,
                    groupName: group.displayName,
                    targetType: group.assignmentTargetType,
                    intent: assignmentIntent  // Use the correct intent here
                )
                assignment.batchId = id

                // Use per-group settings if available, otherwise use global settings
                if let groupSetting = groupSettings?.first(where: { $0.groupId == group.id }) {
                    // Update target type based on assignment mode (include/exclude)
                    if groupSetting.assignmentMode == .exclude {
                        // For exclusion, change the target type
                        assignment.targetType = .exclusionGroup
                    }

                    // Store the app assignment settings in the Assignment's settings property
                    assignment.settings = Assignment.AssignmentSettings(
                        notificationEnabled: true,
                        restartSettings: nil,
                        installTimeSettings: nil,
                        uninstallOnDeviceRemoval: groupSetting.settings.iosVppSettings?.uninstallOnDeviceRemoval,
                        vpnConfigurationId: groupSetting.settings.iosVppSettings?.vpnConfigurationId
                    )

                    // IMPORTANT: For uninstall intent, don't include ANY settings - let Intune use defaults
                    if assignmentIntent == .uninstall {
                        // Don't set any VPP settings for uninstall intent
                        // Intune will handle the licensing automatically
                        assignment.graphSettings = nil
                    } else {
                        // Store the settings for non-uninstall intents
                        assignment.graphSettings = groupSetting.settings
                    }

                    if let filterId = groupSetting.assignmentFilterId, !filterId.isEmpty {
                        let mode = groupSetting.assignmentFilterMode ?? .include
                        let filterType = Assignment.AssignmentFilter.FilterType(rawValue: mode.rawValue) ?? .include
                        assignment.filter = Assignment.AssignmentFilter(
                            filterId: filterId,
                            filterType: filterType,
                            filterExpression: nil
                        )
                    } else {
                        assignment.filter = nil
                    }
                } else {
                    assignment.settings = settings

                    // For uninstall intent, don't include ANY settings - let Intune use defaults
                    if assignmentIntent == .uninstall {
                        assignment.graphSettings = nil
                    } else {
                        // Store settings for non-uninstall intents
                        assignment.graphSettings = settings != nil ? AppAssignmentSettings(intent: assignmentIntent) : nil
                    }
                    assignment.filter = nil
                }

                assignment.scheduledDate = scheduledDate
                assignments.append(assignment)
            }
        }

        return assignments
    }
}
