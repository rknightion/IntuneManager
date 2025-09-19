import Foundation
import Combine

@MainActor
class GroupService: ObservableObject {
    static let shared = GroupService()

    @Published var groups: [DeviceGroup] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastSync: Date?

    private let apiClient = GraphAPIClient.shared
    private let cache = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        loadCachedGroups()
    }

    // MARK: - Public Methods

    func fetchGroups(forceRefresh: Bool = false) async throws -> [DeviceGroup] {
        if !forceRefresh, let cachedGroups = getCachedGroups() {
            self.groups = cachedGroups
            return cachedGroups
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let endpoint = "/groups"
            let parameters = [
                "$select": "id,displayName,description,createdDateTime,groupTypes,membershipRule,membershipRuleProcessingState,securityEnabled,mailEnabled,mailNickname",
                "$filter": "securityEnabled eq true",
                "$orderby": "displayName",
                "$count": "true"
            ]

            let headers = ["ConsistencyLevel": "eventual"]

            let fetchedGroups: [DeviceGroup] = try await apiClient.getAllPages(endpoint, parameters: parameters, headers: headers)

            // Filter for groups that can be used for device assignment
            let filteredGroups = fetchedGroups.filter { group in
                // Include security groups and dynamic groups
                group.securityEnabled || group.isDynamicGroup
            }

            self.groups = filteredGroups
            self.lastSync = Date()

            // Fetch member counts for each group asynchronously
            await fetchMemberCounts(for: filteredGroups)

            // Cache the groups
            await cacheGroups(filteredGroups)

            Logger.shared.info("Fetched \(filteredGroups.count) groups from Graph API")

            return filteredGroups
        } catch {
            self.error = error
            Logger.shared.error("Failed to fetch groups: \(error)")
            throw error
        }
    }

    func fetchGroup(id: String) async throws -> DeviceGroup {
        let endpoint = "/groups/\(id)"
        let parameters = [
            "$select": "id,displayName,description,createdDateTime,groupTypes,membershipRule,membershipRuleProcessingState,securityEnabled,mailEnabled"
        ]

        let group: DeviceGroup = try await apiClient.get(endpoint, parameters: parameters)

        // Fetch member count
        await fetchMemberCount(for: group)

        return group
    }

    func searchGroups(query: String) -> [DeviceGroup] {
        guard !query.isEmpty else { return groups }

        return groups.filter { group in
            group.displayName.localizedCaseInsensitiveContains(query) ||
            group.description?.localizedCaseInsensitiveContains(query) == true
        }
    }

    func filterGroups(by criteria: GroupFilterCriteria) -> [DeviceGroup] {
        var filtered = groups

        if criteria.onlyDynamicGroups {
            filtered = filtered.filter { $0.isDynamicGroup }
        }

        if criteria.onlySecurityGroups {
            filtered = filtered.filter { $0.securityEnabled }
        }

        if criteria.onlyMailEnabledGroups {
            filtered = filtered.filter { $0.mailEnabled }
        }

        if let minMemberCount = criteria.minMemberCount {
            filtered = filtered.filter { ($0.memberCount ?? 0) >= minMemberCount }
        }

        return filtered
    }

    // MARK: - Group Members

    func fetchGroupMembers(groupId: String) async throws -> [GroupMember] {
        let endpoint = "/groups/\(groupId)/members"
        let parameters = [
            "$select": "id,displayName,userPrincipalName,mail",
            "$count": "true"
        ]
        let headers = ["ConsistencyLevel": "eventual"]

        struct MembersResponse: Decodable {
            let value: [GroupMember]
        }

        let response: MembersResponse = try await apiClient.get(endpoint, parameters: parameters, headers: headers)
        return response.value
    }

    func addMemberToGroup(groupId: String, memberId: String) async throws {
        let endpoint = "/groups/\(groupId)/members/$ref"

        struct AddMemberBody: Encodable {
            let odataId: String

            enum CodingKeys: String, CodingKey {
                case odataId = "@odata.id"
            }
        }

        let body = AddMemberBody(odataId: "https://graph.microsoft.com/v1.0/directoryObjects/\(memberId)")

        try await apiClient.post(endpoint, body: body, headers: nil) as EmptyResponse

        Logger.shared.info("Added member \(memberId) to group \(groupId)")
    }

    func removeMemberFromGroup(groupId: String, memberId: String) async throws {
        let endpoint = "/groups/\(groupId)/members/\(memberId)/$ref"

        try await apiClient.delete(endpoint)

        Logger.shared.info("Removed member \(memberId) from group \(groupId)")
    }

    // MARK: - Group Management

    func createGroup(_ group: CreateGroupRequest) async throws -> DeviceGroup {
        let endpoint = "/groups"

        let createdGroup: DeviceGroup = try await apiClient.post(endpoint, body: group)

        Logger.shared.info("Created group: \(createdGroup.displayName)")

        // Refresh groups
        _ = try await fetchGroups(forceRefresh: true)

        return createdGroup
    }

    func updateGroup(groupId: String, updates: UpdateGroupRequest) async throws -> DeviceGroup {
        let endpoint = "/groups/\(groupId)"

        let updatedGroup: DeviceGroup = try await apiClient.patch(endpoint, body: updates)

        Logger.shared.info("Updated group: \(updatedGroup.displayName)")

        // Refresh groups
        _ = try await fetchGroups(forceRefresh: true)

        return updatedGroup
    }

    func deleteGroup(groupId: String) async throws {
        let endpoint = "/groups/\(groupId)"

        try await apiClient.delete(endpoint)

        Logger.shared.info("Deleted group: \(groupId)")

        // Remove from local list
        groups.removeAll { $0.id == groupId }
    }

    // MARK: - Batch Operations

    func fetchGroupsWithAssignedApps(_ groupIds: [String]) async throws -> [(group: DeviceGroup, apps: [Application])] {
        var results: [(DeviceGroup, [Application])] = []

        // Fetch groups in parallel
        await withTaskGroup(of: (DeviceGroup?, [Application]?).self) { group in
            for groupId in groupIds {
                group.addTask {
                    do {
                        let deviceGroup = try await self.fetchGroup(id: groupId)
                        let apps = try await self.fetchAssignedApps(for: groupId)
                        return (deviceGroup, apps)
                    } catch {
                        Logger.shared.error("Failed to fetch group \(groupId): \(error)")
                        return (nil, nil)
                    }
                }
            }

            for await result in group {
                if let deviceGroup = result.0, let apps = result.1 {
                    results.append((deviceGroup, apps))
                }
            }
        }

        return results
    }

    private func fetchAssignedApps(for groupId: String) async throws -> [Application] {
        // This would need to query app assignments and filter by group
        // For now, returning empty array as placeholder
        return []
    }

    // MARK: - Private Methods

    private func fetchMemberCounts(for groups: [DeviceGroup]) async {
        await withTaskGroup(of: (String, Int?).self) { taskGroup in
            for group in groups {
                taskGroup.addTask {
                    do {
                        let count = try await self.fetchMemberCount(groupId: group.id)
                        return (group.id, count)
                    } catch {
                        Logger.shared.error("Failed to fetch member count for group \(group.id): \(error)")
                        return (group.id, nil)
                    }
                }
            }

            for await (groupId, count) in taskGroup {
                if let index = self.groups.firstIndex(where: { $0.id == groupId }),
                   let count = count {
                    self.groups[index].memberCount = count
                }
            }
        }
    }

    private func fetchMemberCount(for group: DeviceGroup) async {
        do {
            let count = try await fetchMemberCount(groupId: group.id)
            if let index = groups.firstIndex(where: { $0.id == group.id }) {
                groups[index].memberCount = count
            }
        } catch {
            Logger.shared.error("Failed to fetch member count for group \(group.id): \(error)")
        }
    }

    private func fetchMemberCount(groupId: String) async throws -> Int {
        let endpoint = "/groups/\(groupId)/members/$count"
        let headers = ["ConsistencyLevel": "eventual"]

        struct CountResponse: Decodable {
            let value: Int
        }

        let response: CountResponse = try await apiClient.get(endpoint, headers: headers)
        return response.value
    }

    private func loadCachedGroups() {
        if let cachedGroups = getCachedGroups() {
            self.groups = cachedGroups
        }
    }

    private func getCachedGroups() -> [DeviceGroup]? {
        return cache.getObject(forKey: "groups", type: [DeviceGroup].self)
    }

    private func cacheGroups(_ groups: [DeviceGroup]) async {
        cache.setObject(groups, forKey: "groups", expiration: .hours(1))
    }
}

// MARK: - Supporting Types

struct GroupFilterCriteria {
    var onlyDynamicGroups: Bool = false
    var onlySecurityGroups: Bool = false
    var onlyMailEnabledGroups: Bool = false
    var minMemberCount: Int?
    var searchQuery: String?
}

struct CreateGroupRequest: Encodable {
    let displayName: String
    let description: String?
    let mailEnabled: Bool
    let mailNickname: String?
    let securityEnabled: Bool
    let groupTypes: [String]?
    let membershipRule: String?
    let membershipRuleProcessingState: String?
}

struct UpdateGroupRequest: Encodable {
    let displayName: String?
    let description: String?
    let membershipRule: String?
}

// Empty response for operations that don't return data
private struct EmptyResponse: Decodable {}