import SwiftUI
import Combine

struct ConfigurationAssignmentView: View {
    let profile: ConfigurationProfile
    @StateObject private var viewModel = ConfigurationAssignmentViewModel()
    @State private var selectedGroups: Set<String> = []
    @State private var selectedExclusionGroups: Set<String> = []
    @State private var includeAllUsers = false
    @State private var includeAllDevices = false
    @State private var searchText = ""
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick Assignment Options
                VStack(spacing: 12) {
                    Toggle(isOn: $includeAllUsers) {
                        Label("All Users", systemImage: "person.2.fill")
                            .font(.headline)
                    }
                    .toggleStyle(.switch)
                    .disabled(includeAllDevices)

                    Toggle(isOn: $includeAllDevices) {
                        Label("All Devices", systemImage: "laptopcomputer")
                            .font(.headline)
                    }
                    .toggleStyle(.switch)
                    .disabled(includeAllUsers)

                    if includeAllUsers || includeAllDevices {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text(includeAllUsers ?
                                "This profile will be assigned to all users in your organization" :
                                "This profile will be assigned to all devices in your organization")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Theme.Colors.secondaryBackground)

                Divider()

                // Group Selection
                if !includeAllUsers && !includeAllDevices {
                    VStack(spacing: 0) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Search groups...", text: $searchText)
                                .textFieldStyle(.plain)
                            if !searchText.isEmpty {
                                Button(action: { searchText = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        .padding()

                        // Group Lists
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Include Groups
                                GroupSection(
                                    title: "Include Groups",
                                    icon: "person.3.fill",
                                    groups: viewModel.filteredGroups(searchText: searchText),
                                    selectedGroups: $selectedGroups,
                                    isExclusion: false
                                )

                                Divider()

                                // Exclude Groups
                                GroupSection(
                                    title: "Exclude Groups",
                                    icon: "person.3.slash",
                                    groups: viewModel.filteredGroups(searchText: searchText),
                                    selectedGroups: $selectedExclusionGroups,
                                    isExclusion: true
                                )
                            }
                            .padding()
                        }
                    }
                }

                // Summary Section
                if !selectedGroups.isEmpty || !selectedExclusionGroups.isEmpty || includeAllUsers || includeAllDevices {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assignment Summary")
                            .font(.headline)

                        if includeAllUsers {
                            Label("All Users", systemImage: "person.2.fill")
                                .foregroundColor(.blue)
                        } else if includeAllDevices {
                            Label("All Devices", systemImage: "laptopcomputer")
                                .foregroundColor(.blue)
                        } else {
                            if !selectedGroups.isEmpty {
                                Label("\(selectedGroups.count) included group(s)", systemImage: "person.3.fill")
                                    .foregroundColor(.green)
                            }
                            if !selectedExclusionGroups.isEmpty {
                                Label("\(selectedExclusionGroups.count) excluded group(s)", systemImage: "person.3.slash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.Colors.secondaryBackground)
                    .cornerRadius(8)
                    .padding()
                }
            }
            .navigationTitle("Manage Assignments")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveAssignments()
                        }
                    }
                    .disabled(isSaving || (!includeAllUsers && !includeAllDevices && selectedGroups.isEmpty))
                }
            }
            .task {
                await viewModel.loadGroups()
                await loadExistingAssignments()
            }
        }
    }

    private func loadExistingAssignments() async {
        guard let assignments = profile.assignments else { return }

        for assignment in assignments {
            switch assignment.target.type {
            case .allUsers:
                includeAllUsers = true
            case .allDevices:
                includeAllDevices = true
            case .group:
                if let groupId = assignment.target.groupId {
                    selectedGroups.insert(groupId)
                }
            case .exclusionGroup:
                if let groupId = assignment.target.groupId {
                    selectedExclusionGroups.insert(groupId)
                }
            default:
                break
            }
        }
    }

    private func saveAssignments() async {
        isSaving = true
        defer { isSaving = false }

        var assignments: [ConfigurationAssignment] = []

        if includeAllUsers {
            assignments.append(ConfigurationAssignment(
                profileId: profile.id,
                target: ConfigurationAssignment.AssignmentTarget(
                    type: .allUsers,
                    groupId: nil,
                    groupName: nil
                )
            ))
        } else if includeAllDevices {
            assignments.append(ConfigurationAssignment(
                profileId: profile.id,
                target: ConfigurationAssignment.AssignmentTarget(
                    type: .allDevices,
                    groupId: nil,
                    groupName: nil
                )
            ))
        } else {
            // Add included groups
            for groupId in selectedGroups {
                if let group = viewModel.groups.first(where: { $0.id == groupId }) {
                    assignments.append(ConfigurationAssignment(
                        profileId: profile.id,
                        target: ConfigurationAssignment.AssignmentTarget(
                            type: .group,
                            groupId: groupId,
                            groupName: group.displayName
                        )
                    ))
                }
            }

            // Add excluded groups
            for groupId in selectedExclusionGroups {
                if let group = viewModel.groups.first(where: { $0.id == groupId }) {
                    assignments.append(ConfigurationAssignment(
                        profileId: profile.id,
                        target: ConfigurationAssignment.AssignmentTarget(
                            type: .exclusionGroup,
                            groupId: groupId,
                            groupName: group.displayName
                        )
                    ))
                }
            }
        }

        await viewModel.updateAssignments(
            profileId: profile.id,
            assignments: assignments,
            isSettingsCatalog: profile.profileType == .settingsCatalog
        )

        if viewModel.error == nil {
            dismiss()
        }
    }
}

struct GroupSection: View {
    let title: String
    let icon: String
    let groups: [DeviceGroup]
    @Binding var selectedGroups: Set<String>
    let isExclusion: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(isExclusion ? .red : .green)

            if groups.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text("No groups found")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else {
                ForEach(groups) { group in
                    GroupRow(
                        group: group,
                        isSelected: selectedGroups.contains(group.id),
                        isExclusion: isExclusion
                    ) {
                        if selectedGroups.contains(group.id) {
                            selectedGroups.remove(group.id)
                        } else {
                            selectedGroups.insert(group.id)
                        }
                    }
                }
            }
        }
    }
}

struct GroupRow: View {
    let group: DeviceGroup
    let isSelected: Bool
    let isExclusion: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? (isExclusion ? .red : .green) : .gray)

                VStack(alignment: .leading) {
                    Text(group.displayName)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    if let description = group.groupDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if let memberCount = group.memberCount {
                    Text("\(memberCount) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isSelected ?
                (isExclusion ? Color.red.opacity(0.1) : Color.green.opacity(0.1)) :
                Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

@MainActor
final class ConfigurationAssignmentViewModel: ObservableObject {
    @Published var groups: [DeviceGroup] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let groupService = GroupService.shared
    private let configurationService = ConfigurationService.shared

    func loadGroups() async {
        isLoading = true
        defer { isLoading = false }

        do {
            groups = try await groupService.fetchGroups()
            Logger.shared.info("Loaded \(groups.count) groups for assignment", category: .ui)
        } catch {
            self.error = error
            Logger.shared.error("Failed to load groups: \(error)", category: .network)
        }
    }

    func filteredGroups(searchText: String) -> [DeviceGroup] {
        guard !searchText.isEmpty else { return groups }
        return groups.filter { group in
            group.displayName.localizedCaseInsensitiveContains(searchText) ||
            (group.groupDescription?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    func updateAssignments(profileId: String, assignments: [ConfigurationAssignment], isSettingsCatalog: Bool) async {
        error = nil

        do {
            try await configurationService.updateProfileAssignments(
                profileId: profileId,
                assignments: assignments,
                isSettingsCatalog: isSettingsCatalog
            )
            Logger.shared.info("Successfully updated assignments for profile: \(profileId)", category: .ui)
        } catch {
            self.error = error
            Logger.shared.error("Failed to update assignments: \(error)", category: .network)
        }
    }
}

#Preview {
    ConfigurationAssignmentView(
        profile: ConfigurationProfile(
            id: "test-id",
            displayName: "Test Profile",
            profileDescription: "Test Description",
            platformType: .iOS,
            profileType: .settingsCatalog
        )
    )
}
