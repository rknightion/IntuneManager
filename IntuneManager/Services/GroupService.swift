import Foundation
import Combine

// MARK: - Helper Types for GroupService

fileprivate struct MembersResponse: Decodable, Sendable {
    let value: [GroupMember]
}

fileprivate struct OwnersResponse: Decodable, Sendable {
    let value: [GroupOwner]
}

fileprivate struct AddMemberBody: Encodable, Sendable {
    let odataId: String

    enum CodingKeys: String, CodingKey {
        case odataId = "@odata.id"
    }
}

fileprivate struct CountResponse: Decodable, Sendable {
    let value: Int
}

final class GroupService: ObservableObject {
    static let shared = GroupService()

    @Published var groups: [DeviceGroup] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var lastSync: Date?

    private let apiClient = GraphAPIClient.shared
    private let dataStore = LocalDataStore.shared
    private let cacheManager = CacheManager.shared

    private init() {
        groups = dataStore.fetchGroups()
    }

    // MARK: - Public Methods

    func fetchGroups(forceRefresh: Bool = false) async throws -> [DeviceGroup] {
        Logger.shared.info("Fetching groups (forceRefresh: \(forceRefresh))", category: .data)

        // Use CacheManager to determine if we should use cache
        if cacheManager.canUseCache(for: .groups) && !forceRefresh {
            let cached = dataStore.fetchGroups()
            if !cached.isEmpty {
                Logger.shared.info("Using cached groups: \(cached.count) items", category: .data)
                groups = cached
                return cached
            }
            Logger.shared.info("No cached groups found, fetching from API", category: .data)
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

            Logger.shared.info("Requesting groups from Graph API...", category: .network)
            let fetchedGroups: [DeviceGroup] = try await apiClient.getAllPagesForModels(endpoint, parameters: parameters, headers: headers)
            Logger.shared.info("Received \(fetchedGroups.count) groups from API", category: .data)

            // Filter for groups that can be used for device assignment
            let filteredGroups = fetchedGroups.filter { group in
                // Include security groups and dynamic groups
                group.securityEnabled || group.isDynamicGroup
            }

            Logger.shared.info("Filtered to \(filteredGroups.count) assignable groups", category: .data)

            // Update the data store first to maintain context consistency
            dataStore.replaceGroups(with: filteredGroups)

            // Now update the in-memory collection with fresh data from the store
            // This ensures we're working with models attached to the current context
            self.groups = dataStore.fetchGroups()
            self.lastSync = Date()

            cacheManager.updateMetadata(for: .groups, recordCount: filteredGroups.count)
            Logger.shared.info("Stored \(filteredGroups.count) groups in cache", category: .data)

            // Fetch member counts for each group asynchronously AFTER updating self.groups
            Logger.shared.info("Fetching member counts for groups...", category: .data)
            await fetchMemberCounts(for: self.groups)

            // Persist the updated member counts back to the data store
            Logger.shared.info("Persisting member counts to data store...", category: .data)
            dataStore.replaceGroups(with: self.groups)

            // Refresh groups from store to ensure UI observes the changes
            self.groups = dataStore.fetchGroups()

            return filteredGroups
        } catch {
            self.error = error
            Logger.shared.error("Failed to fetch groups: \(error.localizedDescription)", category: .data)
            throw error
        }
    }

    func fetchGroup(id: String) async throws -> DeviceGroup {
        let endpoint = "/groups/\(id)"
        let parameters = [
            "$select": "id,displayName,description,createdDateTime,groupTypes,membershipRule,membershipRuleProcessingState,securityEnabled,mailEnabled"
        ]

        let group: DeviceGroup = try await apiClient.getModel(endpoint, parameters: parameters)

        // Fetch member count
        await fetchMemberCount(for: group)

        return group
    }

    func searchGroups(query: String) -> [DeviceGroup] {
        guard !query.isEmpty else { return groups }

        return groups.filter { group in
            group.displayName.localizedCaseInsensitiveContains(query) ||
            group.groupDescription?.localizedCaseInsensitiveContains(query) == true
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
        // Request fields for all member types: users, devices, groups, and service principals
        let parameters = [
            "$select": "id,displayName,userPrincipalName,mail,deviceId,operatingSystem,operatingSystemVersion,accountEnabled,groupTypes,securityEnabled",
            "$count": "true"
        ]
        let headers = ["ConsistencyLevel": "eventual"]

        let response: MembersResponse = try await apiClient.getModel(endpoint, parameters: parameters, headers: headers)
        return response.value
    }

    // MARK: - Group Owners

    func fetchGroupOwners(groupId: String) async throws -> [GroupOwner] {
        let endpoint = "/groups/\(groupId)/owners"
        let parameters = [
            "$select": "id,displayName,userPrincipalName,mail"
        ]
        let headers = ["ConsistencyLevel": "eventual"]

        let response: OwnersResponse = try await apiClient.getModel(endpoint, parameters: parameters, headers: headers)
        return response.value
    }

    func fetchOwnersForGroups(_ groups: [DeviceGroup]) async {
        Logger.shared.info("Fetching owners for \(groups.count) groups", category: .data)

        for group in groups {
            do {
                let owners = try await fetchGroupOwners(groupId: group.id)
                if let index = self.groups.firstIndex(where: { $0.id == group.id }) {
                    self.groups[index].owners = owners
                }
                Logger.shared.debug("Fetched \(owners.count) owners for group: \(group.displayName)", category: .data)
            } catch {
                Logger.shared.error("Failed to fetch owners for group \(group.id): \(error.localizedDescription)", category: .data)
                // Continue processing other groups instead of failing completely
            }
        }

        Logger.shared.info("Completed fetching owners for groups", category: .data)
    }

    func addMemberToGroup(groupId: String, memberId: String) async throws {
        let endpoint = "/groups/\(groupId)/members/$ref"

        let body = AddMemberBody(odataId: "https://graph.microsoft.com/v1.0/directoryObjects/\(memberId)")

        let _: EmptyResponse = try await apiClient.postModel(endpoint, body: body, headers: nil)

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

        let createdGroup: DeviceGroup = try await apiClient.postModel(endpoint, body: group)

        Logger.shared.info("Created group: \(createdGroup.displayName)")

        // Refresh groups
        _ = try await fetchGroups(forceRefresh: true)

        return createdGroup
    }

    func updateGroup(groupId: String, updates: UpdateGroupRequest) async throws -> DeviceGroup {
        let endpoint = "/groups/\(groupId)"

        let updatedGroup: DeviceGroup = try await apiClient.patchModel(endpoint, body: updates)

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

        // Fetch groups sequentially since SwiftData models are not Sendable
        // This is a MainActor-isolated method, so we can't use TaskGroup with non-Sendable types
        for groupId in groupIds {
            do {
                let deviceGroup = try await fetchGroup(id: groupId)
                let apps = try await fetchAssignedApps(for: groupId)
                results.append((deviceGroup, apps))
            } catch {
                Logger.shared.error("Failed to fetch group \(groupId): \(error)")
                // Continue with next group instead of failing completely
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
        // Fetch member counts concurrently for better performance
        await withTaskGroup(of: (String, Int?).self) { group in
            for deviceGroup in groups {
                group.addTask {
                    do {
                        let count = try await self.fetchMemberCount(groupId: deviceGroup.id)
                        return (deviceGroup.id, count)
                    } catch {
                        Logger.shared.error("Failed to fetch member count for group \(deviceGroup.id): \(error)", category: .data)
                        return (deviceGroup.id, nil)
                    }
                }
            }

            // Collect results and update groups
            for await (groupId, count) in group {
                if let count = count,
                   let index = self.groups.firstIndex(where: { $0.id == groupId }) {
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

                // Persist the updated member count to the data store
                dataStore.replaceGroups(with: [groups[index]])

                // Refresh the specific group from store
                let updatedGroups = dataStore.fetchGroups()
                if let updatedIndex = updatedGroups.firstIndex(where: { $0.id == group.id }) {
                    groups[index] = updatedGroups[updatedIndex]
                }
            }
        } catch {
            Logger.shared.error("Failed to fetch member count for group \(group.id): \(error)", category: .data)
        }
    }

    private func fetchMemberCount(groupId: String) async throws -> Int {
        let endpoint = "/groups/\(groupId)/members/$count"
        let headers = [
            "ConsistencyLevel": "eventual",
            "Accept": "text/plain"
        ]

        // Use raw data request since count endpoint returns plain text integer
        let request = try await apiClient.buildCountRequest(
            endpoint: endpoint,
            headers: headers
        )

        let data = try await apiClient.performRawRequest(request)

        guard let countString = String(data: data, encoding: .utf8),
              let count = Int(countString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw GraphAPIError.invalidResponse
        }

        return count
    }

    func hydrateFromStore() {
        let cachedGroups = dataStore.fetchGroups()
        if !cachedGroups.isEmpty {
            groups = cachedGroups
        }
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

struct CreateGroupRequest: Encodable, Sendable {
    let displayName: String
    let description: String?
    let mailEnabled: Bool
    let mailNickname: String?
    let securityEnabled: Bool
    let groupTypes: [String]?
    let membershipRule: String?
    let membershipRuleProcessingState: String?
}

struct UpdateGroupRequest: Encodable, Sendable {
    let displayName: String?
    let description: String?
    let membershipRule: String?
}
