import Foundation
import SwiftData

@MainActor
final class LocalDataStore {
    static let shared = LocalDataStore()

    private var modelContext: ModelContext?

    private init() {}

    func configure(with context: ModelContext) {
        modelContext = context
    }

    func reset() {
        guard let context = modelContext else { return }

        do {
            try deleteAll(Device.self, in: context)
            try deleteAll(Application.self, in: context)
            try deleteAll(DeviceGroup.self, in: context)
            try deleteAll(Assignment.self, in: context)
            try context.save()
        } catch {
            Logger.shared.error("Failed to reset LocalDataStore: \(error.localizedDescription)")
        }
    }

    func summary() -> StorageSummary {
        guard let context = modelContext else { return StorageSummary() }

        let deviceCount = (try? context.fetch(FetchDescriptor<Device>()).count) ?? 0
        let appCount = (try? context.fetch(FetchDescriptor<Application>()).count) ?? 0
        let groupCount = (try? context.fetch(FetchDescriptor<DeviceGroup>()).count) ?? 0
        let assignmentCount = (try? context.fetch(FetchDescriptor<Assignment>()).count) ?? 0

        return StorageSummary(devices: deviceCount,
                              applications: appCount,
                              groups: groupCount,
                              assignments: assignmentCount)
    }

    // MARK: - Devices

    func fetchDevices() -> [Device] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<Device>(sortBy: [SortDescriptor(\.deviceName, comparator: .localizedStandard)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func replaceDevices(with devices: [Device]) {
        guard let context = modelContext else { return }

        do {
            // Fetch existing devices
            let descriptor = FetchDescriptor<Device>()
            let existingDevices = try context.fetch(descriptor)

            // Create a dictionary for quick lookup
            var existingDevicesDict: [String: Device] = [:]
            for device in existingDevices {
                existingDevicesDict[device.id] = device
            }

            // Update existing or insert new devices
            for newDevice in devices {
                if let existingDevice = existingDevicesDict[newDevice.id] {
                    // Update existing device properties
                    updateDevice(existingDevice, from: newDevice)
                    existingDevicesDict.removeValue(forKey: newDevice.id)
                } else {
                    // Insert new device
                    context.insert(newDevice)
                }
            }

            // Delete devices that are no longer present
            for (_, deviceToDelete) in existingDevicesDict {
                context.delete(deviceToDelete)
            }

            try context.save()
        } catch {
            Logger.shared.error("Failed to update devices: \(error.localizedDescription)")
            // Fall back to replace if update fails
            replace(models: devices)
        }
    }

    private func updateDevice(_ existing: Device, from new: Device) {
        // Update all device properties
        existing.deviceName = new.deviceName
        existing.model = new.model
        existing.manufacturer = new.manufacturer
        existing.operatingSystem = new.operatingSystem
        existing.osVersion = new.osVersion
        existing.serialNumber = new.serialNumber
        existing.imei = new.imei
        existing.meid = new.meid
        existing.enrolledDateTime = new.enrolledDateTime
        existing.lastSyncDateTime = new.lastSyncDateTime
        existing.complianceState = new.complianceState
        existing.managementState = new.managementState
        existing.ownership = new.ownership
        existing.enrollmentType = new.enrollmentType
        existing.azureADDeviceId = new.azureADDeviceId
        existing.azureADRegistered = new.azureADRegistered
        existing.deviceCategory = new.deviceCategory
        existing.deviceEnrollmentType = new.deviceEnrollmentType
        existing.userPrincipalName = new.userPrincipalName
        existing.userDisplayName = new.userDisplayName
        existing.userId = new.userId
        existing.emailAddress = new.emailAddress
        existing.phoneNumber = new.phoneNumber
        existing.notes = new.notes
        existing.ethernetMacAddress = new.ethernetMacAddress
        existing.wiFiMacAddress = new.wiFiMacAddress
        existing.freeStorageSpace = new.freeStorageSpace
        existing.totalStorageSpace = new.totalStorageSpace
        existing.isEncrypted = new.isEncrypted
        existing.isSupervised = new.isSupervised
        existing.jailBroken = new.jailBroken
        existing.managedDeviceName = new.managedDeviceName
        existing.partnerReportedThreatState = new.partnerReportedThreatState

        // Additional hardware information
        existing.physicalMemoryInBytes = new.physicalMemoryInBytes
        existing.processorArchitecture = new.processorArchitecture
        existing.udid = new.udid
        existing.iccid = new.iccid
        existing.subscriberCarrier = new.subscriberCarrier
        existing.cellularTechnology = new.cellularTechnology
        existing.batteryHealthPercentage = new.batteryHealthPercentage
        existing.batteryChargeCycles = new.batteryChargeCycles
        existing.batteryLevelPercentage = new.batteryLevelPercentage
        existing.ipAddressV4 = new.ipAddressV4
        existing.subnetAddress = new.subnetAddress

        // Management information
        existing.managementCertificateExpirationDate = new.managementCertificateExpirationDate
        existing.exchangeAccessState = new.exchangeAccessState
        existing.exchangeAccessStateReason = new.exchangeAccessStateReason
        existing.exchangeLastSuccessfulSyncDateTime = new.exchangeLastSuccessfulSyncDateTime
        existing.remoteAssistanceSessionUrl = new.remoteAssistanceSessionUrl
        existing.autopilotEnrolled = new.autopilotEnrolled
        existing.requireUserEnrollmentApproval = new.requireUserEnrollmentApproval
        existing.lostModeState = new.lostModeState
        existing.activationLockBypassCode = new.activationLockBypassCode
        existing.deviceRegistrationState = new.deviceRegistrationState
        existing.managementAgent = new.managementAgent
        existing.deviceType = new.deviceType
        existing.chassisType = new.chassisType
        existing.joinType = new.joinType
        existing.skuFamily = new.skuFamily
        existing.skuNumber = new.skuNumber

        // Compliance information
        existing.complianceGracePeriodExpirationDateTime = new.complianceGracePeriodExpirationDateTime
        existing.androidSecurityPatchLevel = new.androidSecurityPatchLevel
        existing.securityPatchLevel = new.securityPatchLevel
        existing.easActivated = new.easActivated
        existing.easDeviceId = new.easDeviceId
        existing.easActivationDateTime = new.easActivationDateTime
        existing.aadRegistered = new.aadRegistered
    }

    // MARK: - Applications

    func fetchApplications() -> [Application] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<Application>(sortBy: [SortDescriptor(\.displayName, comparator: .localizedStandard)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func replaceApplications(with applications: [Application]) {
        guard let context = modelContext else { return }

        do {
            // Fetch existing applications
            let descriptor = FetchDescriptor<Application>()
            let existingApps = try context.fetch(descriptor)

            // Create a dictionary for quick lookup
            var existingAppsDict: [String: Application] = [:]
            for app in existingApps {
                existingAppsDict[app.id] = app
            }

            // Update existing or insert new applications
            for newApp in applications {
                if let existingApp = existingAppsDict[newApp.id] {
                    // Update existing app properties
                    updateApplication(existingApp, from: newApp)
                    existingAppsDict.removeValue(forKey: newApp.id)
                } else {
                    // Insert new app
                    context.insert(newApp)
                }
            }

            // Delete applications that are no longer present
            for (_, appToDelete) in existingAppsDict {
                context.delete(appToDelete)
            }

            try context.save()
        } catch {
            Logger.shared.error("Failed to update applications: \(error.localizedDescription)")
            // Fall back to replace if update fails
            replace(models: applications)
        }
    }

    private func updateApplication(_ existing: Application, from new: Application) {
        existing.displayName = new.displayName
        existing.appDescription = new.appDescription
        existing.publisher = new.publisher
        existing.largeIcon = new.largeIcon
        existing.createdDateTime = new.createdDateTime
        existing.lastModifiedDateTime = new.lastModifiedDateTime
        existing.isFeatured = new.isFeatured
        existing.privacyInformationUrl = new.privacyInformationUrl
        existing.informationUrl = new.informationUrl
        existing.owner = new.owner
        existing.developer = new.developer
        existing.notes = new.notes
        existing.publishingState = new.publishingState
        existing.appType = new.appType
        existing.version = new.version
        existing.fileName = new.fileName
        existing.size = new.size
        existing.minimumSupportedOperatingSystem = new.minimumSupportedOperatingSystem
        existing.bundleId = new.bundleId
        existing.appStoreUrl = new.appStoreUrl
        existing.applicableDeviceType = new.applicableDeviceType
        existing.installCommandLine = new.installCommandLine
        existing.uninstallCommandLine = new.uninstallCommandLine
        existing.ignoreVersionDetection = new.ignoreVersionDetection

        // Update assignments - handle carefully to avoid context issues
        // Only update if assignments are provided and not nil
        if let newAssignments = new.assignments {
            existing.assignments = newAssignments
        }
        // Update install summary
        if let newSummary = new.installSummary {
            existing.installSummary = newSummary
        }
    }

    // MARK: - Device Groups

    func fetchGroups() -> [DeviceGroup] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<DeviceGroup>(sortBy: [SortDescriptor(\.displayName, comparator: .localizedStandard)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func replaceGroups(with groups: [DeviceGroup]) {
        guard let context = modelContext else { return }

        do {
            // Fetch existing groups
            let descriptor = FetchDescriptor<DeviceGroup>()
            let existingGroups = try context.fetch(descriptor)

            // Create a dictionary for quick lookup
            var existingGroupsDict: [String: DeviceGroup] = [:]
            for group in existingGroups {
                existingGroupsDict[group.id] = group
            }

            // Update existing or insert new groups
            for newGroup in groups {
                if let existingGroup = existingGroupsDict[newGroup.id] {
                    // Update existing group properties
                    updateDeviceGroup(existingGroup, from: newGroup)
                    existingGroupsDict.removeValue(forKey: newGroup.id)
                } else {
                    // Insert new group
                    context.insert(newGroup)
                }
            }

            // Delete groups that are no longer present
            for (_, groupToDelete) in existingGroupsDict {
                context.delete(groupToDelete)
            }

            try context.save()
        } catch {
            Logger.shared.error("Failed to update device groups: \(error.localizedDescription)")
            // Fall back to replace if update fails
            replace(models: groups)
        }
    }

    private func updateDeviceGroup(_ existing: DeviceGroup, from new: DeviceGroup) {
        existing.displayName = new.displayName
        existing.groupDescription = new.groupDescription
        existing.createdDateTime = new.createdDateTime
        existing.groupTypesData = new.groupTypesData
        existing.membershipRule = new.membershipRule
        existing.membershipRuleProcessingState = new.membershipRuleProcessingState
        existing.securityEnabled = new.securityEnabled
        existing.mailEnabled = new.mailEnabled
        existing.mailNickname = new.mailNickname
        existing.onPremisesSyncEnabled = new.onPremisesSyncEnabled
        existing.proxyAddressesData = new.proxyAddressesData
        existing.visibility = new.visibility
        existing.allowExternalSenders = new.allowExternalSenders
        existing.autoSubscribeNewMembers = new.autoSubscribeNewMembers
        existing.isSubscribedByMail = new.isSubscribedByMail
        existing.unseenCount = new.unseenCount

        // Group statistics
        existing.memberCount = new.memberCount
        existing.deviceCount = new.deviceCount
        existing.userCount = new.userCount

        // Note: Relationships (assignedApplications, members) are @Transient
        // and not persisted, so we don't update them here
    }

    // MARK: - Assignments

    func fetchAssignments(limit: Int = 1000) -> [Assignment] {
        guard let context = modelContext else { return [] }
        var descriptor = FetchDescriptor<Assignment>(sortBy: [SortDescriptor(\.createdDate, order: .reverse)])
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func storeAssignments(_ assignments: [Assignment]) {
        replace(models: assignments)
    }

    // MARK: - Helpers

    private func replace<T: PersistentModel>(models: [T]) {
        guard let context = modelContext else { return }

        do {
            try deleteAll(T.self, in: context)
            for model in models {
                context.insert(model)
            }
            try context.save()
        } catch {
            Logger.shared.error("Failed to replace \(T.self) records: \(error.localizedDescription)")
        }
    }

    private func deleteAll<T: PersistentModel>(_: T.Type, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<T>()
        let existing = try context.fetch(descriptor)
        for object in existing {
            context.delete(object)
        }
    }
}

// MARK: - Storage Summary

struct StorageSummary: Sendable {
    let devices: Int
    let applications: Int
    let groups: Int
    let assignments: Int

    init(devices: Int = 0, applications: Int = 0, groups: Int = 0, assignments: Int = 0) {
        self.devices = devices
        self.applications = applications
        self.groups = groups
        self.assignments = assignments
    }

    var formatted: String {
        "\(devices) devices • \(applications) apps • \(groups) groups • \(assignments) assignments"
    }
}
