import Foundation
import SwiftData

@Model
final class Device: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var deviceName: String
    var model: String?
    var manufacturer: String?
    var operatingSystem: String
    var osVersion: String?
    var serialNumber: String?
    var imei: String?
    var meid: String?
    var enrolledDateTime: Date
    var lastSyncDateTime: Date?
    var complianceState: ComplianceState
    var managementState: ManagementState
    var ownership: Ownership
    var enrollmentType: String?
    var azureADDeviceId: String?
    var azureADRegistered: Bool
    var deviceCategory: String?
    var deviceEnrollmentType: String?
    var userPrincipalName: String?
    var userDisplayName: String?
    var userId: String?
    var emailAddress: String?
    var phoneNumber: String?
    var notes: String?
    var ethernetMacAddress: String?
    var wiFiMacAddress: String?
    var freeStorageSpace: Int64?
    var totalStorageSpace: Int64?
    var isEncrypted: Bool
    var isSupervised: Bool
    var jailBroken: String?
    var managedDeviceName: String?
    var partnerReportedThreatState: String?

    // Relationships
    var installedApps: [InstalledApp]?
    var assignedGroups: [DeviceGroup]?

    enum ComplianceState: String, Codable, CaseIterable {
        case unknown
        case compliant
        case noncompliant
        case conflict
        case error
        case inGracePeriod
        case configManager

        var displayColor: String {
            switch self {
            case .compliant: return "green"
            case .noncompliant: return "red"
            case .inGracePeriod: return "orange"
            case .unknown, .conflict, .error, .configManager: return "gray"
            }
        }

        var displayName: String {
            switch self {
            case .unknown: return "Unknown"
            case .compliant: return "Compliant"
            case .noncompliant: return "Non-compliant"
            case .conflict: return "Conflict"
            case .error: return "Error"
            case .inGracePeriod: return "In Grace Period"
            case .configManager: return "Config Manager"
            }
        }
    }

    enum ManagementState: String, Codable, CaseIterable {
        case managed
        case retirePending
        case retireFailed
        case wipePending
        case wipeFailed
        case unhealthy
        case deletePending
        case retireIssued
        case wipeIssued
        case wipeCanceled
        case retireCanceled
        case discovered

        var displayName: String {
            switch self {
            case .managed: return "Managed"
            case .retirePending: return "Retire Pending"
            case .retireFailed: return "Retire Failed"
            case .wipePending: return "Wipe Pending"
            case .wipeFailed: return "Wipe Failed"
            case .unhealthy: return "Unhealthy"
            case .deletePending: return "Delete Pending"
            case .retireIssued: return "Retire Issued"
            case .wipeIssued: return "Wipe Issued"
            case .wipeCanceled: return "Wipe Canceled"
            case .retireCanceled: return "Retire Canceled"
            case .discovered: return "Discovered"
            }
        }
    }

    enum Ownership: String, Codable, CaseIterable {
        case unknown
        case company
        case personal
        case shared

        var displayName: String {
            switch self {
            case .unknown: return "Unknown"
            case .company: return "Corporate"
            case .personal: return "Personal"
            case .shared: return "Shared"
            }
        }
    }

    init(id: String,
         deviceName: String,
         operatingSystem: String,
         enrolledDateTime: Date = Date(),
         complianceState: ComplianceState = .unknown,
         managementState: ManagementState = .managed,
         ownership: Ownership = .unknown,
         isEncrypted: Bool = false,
         isSupervised: Bool = false) {
        self.id = id
        self.deviceName = deviceName
        self.operatingSystem = operatingSystem
        self.enrolledDateTime = enrolledDateTime
        self.complianceState = complianceState
        self.managementState = managementState
        self.ownership = ownership
        self.isEncrypted = isEncrypted
        self.isSupervised = isSupervised
        self.azureADRegistered = false
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case id
        case deviceName
        case model
        case manufacturer
        case operatingSystem
        case osVersion
        case serialNumber
        case imei
        case meid
        case enrolledDateTime
        case lastSyncDateTime
        case complianceState
        case managementState
        case ownership = "managedDeviceOwnerType"
        case enrollmentType
        case azureADDeviceId
        case azureADRegistered
        case deviceCategory
        case deviceEnrollmentType
        case userPrincipalName
        case userDisplayName
        case userId
        case emailAddress
        case phoneNumber
        case notes
        case ethernetMacAddress
        case wiFiMacAddress
        case freeStorageSpace
        case totalStorageSpace
        case isEncrypted
        case isSupervised
        case jailBroken
        case managedDeviceName
        case partnerReportedThreatState
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        manufacturer = try container.decodeIfPresent(String.self, forKey: .manufacturer)
        operatingSystem = try container.decode(String.self, forKey: .operatingSystem)
        osVersion = try container.decodeIfPresent(String.self, forKey: .osVersion)
        serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        imei = try container.decodeIfPresent(String.self, forKey: .imei)
        meid = try container.decodeIfPresent(String.self, forKey: .meid)
        enrolledDateTime = try container.decode(Date.self, forKey: .enrolledDateTime)
        lastSyncDateTime = try container.decodeIfPresent(Date.self, forKey: .lastSyncDateTime)
        complianceState = try container.decode(ComplianceState.self, forKey: .complianceState)
        managementState = try container.decode(ManagementState.self, forKey: .managementState)
        ownership = try container.decode(Ownership.self, forKey: .ownership)
        enrollmentType = try container.decodeIfPresent(String.self, forKey: .enrollmentType)
        azureADDeviceId = try container.decodeIfPresent(String.self, forKey: .azureADDeviceId)
        azureADRegistered = try container.decodeIfPresent(Bool.self, forKey: .azureADRegistered) ?? false
        deviceCategory = try container.decodeIfPresent(String.self, forKey: .deviceCategory)
        deviceEnrollmentType = try container.decodeIfPresent(String.self, forKey: .deviceEnrollmentType)
        userPrincipalName = try container.decodeIfPresent(String.self, forKey: .userPrincipalName)
        userDisplayName = try container.decodeIfPresent(String.self, forKey: .userDisplayName)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        emailAddress = try container.decodeIfPresent(String.self, forKey: .emailAddress)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        ethernetMacAddress = try container.decodeIfPresent(String.self, forKey: .ethernetMacAddress)
        wiFiMacAddress = try container.decodeIfPresent(String.self, forKey: .wiFiMacAddress)
        freeStorageSpace = try container.decodeIfPresent(Int64.self, forKey: .freeStorageSpace)
        totalStorageSpace = try container.decodeIfPresent(Int64.self, forKey: .totalStorageSpace)
        isEncrypted = try container.decodeIfPresent(Bool.self, forKey: .isEncrypted) ?? false
        isSupervised = try container.decodeIfPresent(Bool.self, forKey: .isSupervised) ?? false
        jailBroken = try container.decodeIfPresent(String.self, forKey: .jailBroken)
        managedDeviceName = try container.decodeIfPresent(String.self, forKey: .managedDeviceName)
        partnerReportedThreatState = try container.decodeIfPresent(String.self, forKey: .partnerReportedThreatState)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(deviceName, forKey: .deviceName)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(manufacturer, forKey: .manufacturer)
        try container.encode(operatingSystem, forKey: .operatingSystem)
        try container.encodeIfPresent(osVersion, forKey: .osVersion)
        try container.encodeIfPresent(serialNumber, forKey: .serialNumber)
        try container.encodeIfPresent(imei, forKey: .imei)
        try container.encodeIfPresent(meid, forKey: .meid)
        try container.encode(enrolledDateTime, forKey: .enrolledDateTime)
        try container.encodeIfPresent(lastSyncDateTime, forKey: .lastSyncDateTime)
        try container.encode(complianceState, forKey: .complianceState)
        try container.encode(managementState, forKey: .managementState)
        try container.encode(ownership, forKey: .ownership)
        try container.encodeIfPresent(enrollmentType, forKey: .enrollmentType)
        try container.encodeIfPresent(azureADDeviceId, forKey: .azureADDeviceId)
        try container.encode(azureADRegistered, forKey: .azureADRegistered)
        try container.encodeIfPresent(deviceCategory, forKey: .deviceCategory)
        try container.encodeIfPresent(deviceEnrollmentType, forKey: .deviceEnrollmentType)
        try container.encodeIfPresent(userPrincipalName, forKey: .userPrincipalName)
        try container.encodeIfPresent(userDisplayName, forKey: .userDisplayName)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(emailAddress, forKey: .emailAddress)
        try container.encodeIfPresent(phoneNumber, forKey: .phoneNumber)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(ethernetMacAddress, forKey: .ethernetMacAddress)
        try container.encodeIfPresent(wiFiMacAddress, forKey: .wiFiMacAddress)
        try container.encodeIfPresent(freeStorageSpace, forKey: .freeStorageSpace)
        try container.encodeIfPresent(totalStorageSpace, forKey: .totalStorageSpace)
        try container.encode(isEncrypted, forKey: .isEncrypted)
        try container.encode(isSupervised, forKey: .isSupervised)
        try container.encodeIfPresent(jailBroken, forKey: .jailBroken)
        try container.encodeIfPresent(managedDeviceName, forKey: .managedDeviceName)
        try container.encodeIfPresent(partnerReportedThreatState, forKey: .partnerReportedThreatState)
    }
}

// Helper struct for installed apps
struct InstalledApp: Codable {
    let id: String
    let displayName: String
    let version: String?
    let sizeInBytes: Int64?
}