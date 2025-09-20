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
        replace(models: devices)
    }

    // MARK: - Applications

    func fetchApplications() -> [Application] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<Application>(sortBy: [SortDescriptor(\.displayName, comparator: .localizedStandard)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func replaceApplications(with applications: [Application]) {
        replace(models: applications)
    }

    // MARK: - Device Groups

    func fetchGroups() -> [DeviceGroup] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<DeviceGroup>(sortBy: [SortDescriptor(\.displayName, comparator: .localizedStandard)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func replaceGroups(with groups: [DeviceGroup]) {
        replace(models: groups)
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
