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

    // Additional hardware information
    var physicalMemoryInBytes: Int64?
    var processorArchitecture: String?
    var udid: String?
    var iccid: String?
    var subscriberCarrier: String?
    var cellularTechnology: String?
    var batteryHealthPercentage: Int?
    var batteryChargeCycles: Int?
    var batteryLevelPercentage: Double?
    var ipAddressV4: String?
    var subnetAddress: String?

    // Management information
    var managementCertificateExpirationDate: Date?
    var exchangeAccessState: String?
    var exchangeAccessStateReason: String?
    var exchangeLastSuccessfulSyncDateTime: Date?
    var remoteAssistanceSessionUrl: String?
    var autopilotEnrolled: Bool?
    var requireUserEnrollmentApproval: Bool?
    var lostModeState: String?
    var activationLockBypassCode: String?
    var deviceRegistrationState: String?
    var managementAgent: String?
    var deviceType: String?
    var chassisType: String?
    var joinType: String?
    var skuFamily: String?
    var skuNumber: Int?

    // Compliance information
    var complianceGracePeriodExpirationDateTime: Date?
    var androidSecurityPatchLevel: String?
    var securityPatchLevel: String?
    var easActivated: Bool?
    var easDeviceId: String?
    var easActivationDateTime: Date?
    var aadRegistered: Bool?

    // Security information
    var windowsActiveMalwareCount: Int?
    var windowsRemediatedMalwareCount: Int?
    var bootstrapTokenEscrowed: Bool?
    var deviceFirmwareConfigurationInterfaceManaged: Bool?

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
            case .compliant: return "systemGreen"
            case .noncompliant: return "systemRed"
            case .inGracePeriod: return "systemOrange"
            case .unknown, .conflict, .error, .configManager: return "systemGray"
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
        case physicalMemoryInBytes
        case processorArchitecture
        case udid
        case iccid
        case subscriberCarrier
        case cellularTechnology
        case batteryHealthPercentage
        case batteryChargeCycles
        case batteryLevelPercentage
        case ipAddressV4
        case subnetAddress
        case managementCertificateExpirationDate
        case exchangeAccessState
        case exchangeAccessStateReason
        case exchangeLastSuccessfulSyncDateTime
        case remoteAssistanceSessionUrl
        case autopilotEnrolled
        case requireUserEnrollmentApproval
        case lostModeState
        case activationLockBypassCode
        case deviceRegistrationState
        case managementAgent
        case deviceType
        case chassisType
        case joinType
        case skuFamily
        case skuNumber
        case complianceGracePeriodExpirationDateTime
        case androidSecurityPatchLevel
        case securityPatchLevel
        case easActivated
        case easDeviceId
        case easActivationDateTime
        case aadRegistered
        case windowsActiveMalwareCount
        case windowsRemediatedMalwareCount
        case bootstrapTokenEscrowed
        case deviceFirmwareConfigurationInterfaceManaged
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

        // Additional hardware information
        physicalMemoryInBytes = try container.decodeIfPresent(Int64.self, forKey: .physicalMemoryInBytes)
        processorArchitecture = try container.decodeIfPresent(String.self, forKey: .processorArchitecture)
        udid = try container.decodeIfPresent(String.self, forKey: .udid)
        iccid = try container.decodeIfPresent(String.self, forKey: .iccid)
        subscriberCarrier = try container.decodeIfPresent(String.self, forKey: .subscriberCarrier)
        cellularTechnology = try container.decodeIfPresent(String.self, forKey: .cellularTechnology)
        batteryHealthPercentage = try container.decodeIfPresent(Int.self, forKey: .batteryHealthPercentage)
        batteryChargeCycles = try container.decodeIfPresent(Int.self, forKey: .batteryChargeCycles)
        batteryLevelPercentage = try container.decodeIfPresent(Double.self, forKey: .batteryLevelPercentage)
        ipAddressV4 = try container.decodeIfPresent(String.self, forKey: .ipAddressV4)
        subnetAddress = try container.decodeIfPresent(String.self, forKey: .subnetAddress)

        // Management information
        managementCertificateExpirationDate = try container.decodeIfPresent(Date.self, forKey: .managementCertificateExpirationDate)
        exchangeAccessState = try container.decodeIfPresent(String.self, forKey: .exchangeAccessState)
        exchangeAccessStateReason = try container.decodeIfPresent(String.self, forKey: .exchangeAccessStateReason)
        exchangeLastSuccessfulSyncDateTime = try container.decodeIfPresent(Date.self, forKey: .exchangeLastSuccessfulSyncDateTime)
        remoteAssistanceSessionUrl = try container.decodeIfPresent(String.self, forKey: .remoteAssistanceSessionUrl)
        autopilotEnrolled = try container.decodeIfPresent(Bool.self, forKey: .autopilotEnrolled)
        requireUserEnrollmentApproval = try container.decodeIfPresent(Bool.self, forKey: .requireUserEnrollmentApproval)
        lostModeState = try container.decodeIfPresent(String.self, forKey: .lostModeState)
        activationLockBypassCode = try container.decodeIfPresent(String.self, forKey: .activationLockBypassCode)
        deviceRegistrationState = try container.decodeIfPresent(String.self, forKey: .deviceRegistrationState)
        managementAgent = try container.decodeIfPresent(String.self, forKey: .managementAgent)
        deviceType = try container.decodeIfPresent(String.self, forKey: .deviceType)
        chassisType = try container.decodeIfPresent(String.self, forKey: .chassisType)
        joinType = try container.decodeIfPresent(String.self, forKey: .joinType)
        skuFamily = try container.decodeIfPresent(String.self, forKey: .skuFamily)
        skuNumber = try container.decodeIfPresent(Int.self, forKey: .skuNumber)

        // Compliance information
        complianceGracePeriodExpirationDateTime = try container.decodeIfPresent(Date.self, forKey: .complianceGracePeriodExpirationDateTime)
        androidSecurityPatchLevel = try container.decodeIfPresent(String.self, forKey: .androidSecurityPatchLevel)
        securityPatchLevel = try container.decodeIfPresent(String.self, forKey: .securityPatchLevel)
        easActivated = try container.decodeIfPresent(Bool.self, forKey: .easActivated)
        easDeviceId = try container.decodeIfPresent(String.self, forKey: .easDeviceId)
        easActivationDateTime = try container.decodeIfPresent(Date.self, forKey: .easActivationDateTime)
        aadRegistered = try container.decodeIfPresent(Bool.self, forKey: .aadRegistered)

        // Security information
        windowsActiveMalwareCount = try container.decodeIfPresent(Int.self, forKey: .windowsActiveMalwareCount)
        windowsRemediatedMalwareCount = try container.decodeIfPresent(Int.self, forKey: .windowsRemediatedMalwareCount)
        bootstrapTokenEscrowed = try container.decodeIfPresent(Bool.self, forKey: .bootstrapTokenEscrowed)
        deviceFirmwareConfigurationInterfaceManaged = try container.decodeIfPresent(Bool.self, forKey: .deviceFirmwareConfigurationInterfaceManaged)
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

        // Additional hardware information
        try container.encodeIfPresent(physicalMemoryInBytes, forKey: .physicalMemoryInBytes)
        try container.encodeIfPresent(processorArchitecture, forKey: .processorArchitecture)
        try container.encodeIfPresent(udid, forKey: .udid)
        try container.encodeIfPresent(iccid, forKey: .iccid)
        try container.encodeIfPresent(subscriberCarrier, forKey: .subscriberCarrier)
        try container.encodeIfPresent(cellularTechnology, forKey: .cellularTechnology)
        try container.encodeIfPresent(batteryHealthPercentage, forKey: .batteryHealthPercentage)
        try container.encodeIfPresent(batteryChargeCycles, forKey: .batteryChargeCycles)
        try container.encodeIfPresent(batteryLevelPercentage, forKey: .batteryLevelPercentage)
        try container.encodeIfPresent(ipAddressV4, forKey: .ipAddressV4)
        try container.encodeIfPresent(subnetAddress, forKey: .subnetAddress)

        // Management information
        try container.encodeIfPresent(managementCertificateExpirationDate, forKey: .managementCertificateExpirationDate)
        try container.encodeIfPresent(exchangeAccessState, forKey: .exchangeAccessState)
        try container.encodeIfPresent(exchangeAccessStateReason, forKey: .exchangeAccessStateReason)
        try container.encodeIfPresent(exchangeLastSuccessfulSyncDateTime, forKey: .exchangeLastSuccessfulSyncDateTime)
        try container.encodeIfPresent(remoteAssistanceSessionUrl, forKey: .remoteAssistanceSessionUrl)
        try container.encodeIfPresent(autopilotEnrolled, forKey: .autopilotEnrolled)
        try container.encodeIfPresent(requireUserEnrollmentApproval, forKey: .requireUserEnrollmentApproval)
        try container.encodeIfPresent(lostModeState, forKey: .lostModeState)
        try container.encodeIfPresent(activationLockBypassCode, forKey: .activationLockBypassCode)
        try container.encodeIfPresent(deviceRegistrationState, forKey: .deviceRegistrationState)
        try container.encodeIfPresent(managementAgent, forKey: .managementAgent)
        try container.encodeIfPresent(deviceType, forKey: .deviceType)
        try container.encodeIfPresent(chassisType, forKey: .chassisType)
        try container.encodeIfPresent(joinType, forKey: .joinType)
        try container.encodeIfPresent(skuFamily, forKey: .skuFamily)
        try container.encodeIfPresent(skuNumber, forKey: .skuNumber)

        // Compliance information
        try container.encodeIfPresent(complianceGracePeriodExpirationDateTime, forKey: .complianceGracePeriodExpirationDateTime)
        try container.encodeIfPresent(androidSecurityPatchLevel, forKey: .androidSecurityPatchLevel)
        try container.encodeIfPresent(securityPatchLevel, forKey: .securityPatchLevel)
        try container.encodeIfPresent(easActivated, forKey: .easActivated)
        try container.encodeIfPresent(easDeviceId, forKey: .easDeviceId)
        try container.encodeIfPresent(easActivationDateTime, forKey: .easActivationDateTime)
        try container.encodeIfPresent(aadRegistered, forKey: .aadRegistered)

        // Security information
        try container.encodeIfPresent(windowsActiveMalwareCount, forKey: .windowsActiveMalwareCount)
        try container.encodeIfPresent(windowsRemediatedMalwareCount, forKey: .windowsRemediatedMalwareCount)
        try container.encodeIfPresent(bootstrapTokenEscrowed, forKey: .bootstrapTokenEscrowed)
        try container.encodeIfPresent(deviceFirmwareConfigurationInterfaceManaged, forKey: .deviceFirmwareConfigurationInterfaceManaged)
    }
}

// Helper struct for installed apps
struct InstalledApp: Codable {
    let id: String
    let displayName: String
    let version: String?
    let sizeInBytes: Int64?
}