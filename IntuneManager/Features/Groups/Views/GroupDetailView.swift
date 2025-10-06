import SwiftUI

struct GroupDetailView: View {
    @StateObject private var viewModel: GroupDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0

    init(group: DeviceGroup, initialTab: Int = 0) {
        _viewModel = StateObject(wrappedValue: GroupDetailViewModel(group: group))
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with group info
                    GroupDetailHeaderView(group: viewModel.group)

                    // Tab picker for different sections
                    Picker("Section", selection: $selectedTab) {
                        Text("General").tag(0)
                        Text("Members").tag(1)
                        Text("Owners").tag(2)
                        Text("Assignments").tag(3)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)

                    // Content based on selected tab
                    Group {
                        switch selectedTab {
                        case 0:
                            GroupGeneralSection(group: viewModel.group)
                        case 1:
                            GroupMembersSection(
                                members: viewModel.members,
                                isLoading: viewModel.isLoadingMembers,
                                isBuiltInTarget: viewModel.group.isBuiltInAssignmentTarget
                            )
                        case 2:
                            GroupOwnersSection(
                                owners: viewModel.owners,
                                isLoading: viewModel.isLoadingOwners,
                                isBuiltInTarget: viewModel.group.isBuiltInAssignmentTarget
                            )
                        case 3:
                            GroupAssignmentsSection(
                                apps: viewModel.assignedApps,
                                isLoading: viewModel.isLoadingAssignments,
                                groupId: viewModel.group.id
                            )
                        default:
                            GroupGeneralSection(group: viewModel.group)
                        }
                    }
                    .padding(.horizontal)

                    // Error message if any
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(viewModel.group.displayName)
            #if os(macOS)
            .navigationSubtitle(viewModel.group.groupTypeDisplay)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        Task {
                            await viewModel.refreshAll()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }

                #if os(iOS)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
            .task {
                // Load data for the initially selected tab
                await loadDataForTab(selectedTab)
            }
            .onChange(of: selectedTab) {
                Task {
                    await loadDataForTab(selectedTab)
                }
            }
        }
    }

    private func loadDataForTab(_ tab: Int) async {
        switch tab {
        case 1: // Members
            await viewModel.loadMembers()
        case 2: // Owners
            await viewModel.loadOwners()
        case 3: // Assignments
            await viewModel.loadAssignments()
        default:
            break // General tab doesn't need async loading
        }
    }
}

// MARK: - Group Detail Header

struct GroupDetailHeaderView: View {
    let group: DeviceGroup

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: groupIcon)
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading) {
                    Text(group.displayName)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let description = group.groupDescription, !description.isEmpty {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            // Quick status badges
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    if group.securityEnabled {
                        StatusBadge(icon: "lock.shield.fill", text: "Security", color: .green)
                    }
                    if group.mailEnabled {
                        StatusBadge(icon: "envelope.fill", text: "Mail Enabled", color: .purple)
                    }
                    if group.isDynamicGroup {
                        StatusBadge(icon: "arrow.triangle.2.circlepath", text: "Dynamic", color: .blue)
                    }
                    if group.onPremisesSyncEnabled == true {
                        StatusBadge(icon: "arrow.triangle.branch", text: "On-Prem Synced", color: .orange)
                    }
                    if let memberCount = group.memberCount {
                        StatusBadge(icon: "person.2.fill", text: "\(memberCount) members", color: .secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var groupIcon: String {
        if group.isDynamicGroup {
            return "arrow.triangle.2.circlepath"
        } else if group.securityEnabled {
            return "lock.shield"
        } else if group.mailEnabled {
            return "envelope"
        } else {
            return "person.3"
        }
    }
}

// MARK: - General Section

struct GroupGeneralSection: View {
    let group: DeviceGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupSectionHeader(title: "General Information", icon: "info.circle")

            GroupInfoRow(label: "Display Name", value: group.displayName)

            if let description = group.groupDescription, !description.isEmpty {
                GroupInfoRow(label: "Description", value: description)
            }

            GroupInfoRow(label: "Group Type", value: group.groupTypeDisplay)

            if let createdDate = group.createdDateTime {
                GroupInfoRow(label: "Created", value: createdDate.formatted(date: .abbreviated, time: .shortened))
            }

            if group.isDynamicGroup, let rule = group.membershipRule {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Membership Rule")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(rule)
                        .font(.system(.caption, design: .monospaced))
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }

            if let state = group.membershipRuleProcessingState {
                GroupInfoRow(label: "Rule Status", value: state.displayName)
            }

            if group.onPremisesSyncEnabled == true {
                GroupInfoRow(label: "Sync Status", value: "Synchronized with on-premises")
            }

            if let memberCount = group.memberCount {
                GroupInfoRow(label: "Member Count", value: "\(memberCount)")
            }
        }
    }
}

// MARK: - Members Section

struct GroupMembersSection: View {
    let members: [GroupMember]
    let isLoading: Bool
    let isBuiltInTarget: Bool
    @State private var searchText = ""

    private var filteredMembers: [GroupMember] {
        if searchText.isEmpty {
            return members
        }
        return members.filter { member in
            member.effectiveDisplayName.localizedCaseInsensitiveContains(searchText) ||
            member.displayName?.localizedCaseInsensitiveContains(searchText) == true ||
            member.userPrincipalName?.localizedCaseInsensitiveContains(searchText) == true ||
            member.deviceId?.localizedCaseInsensitiveContains(searchText) == true ||
            member.mail?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupSectionHeader(title: "Group Members", icon: "person.2")

            if isBuiltInTarget {
                Text("Built-in targets do not have direct members.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading members...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if members.isEmpty {
                Text("No members in this group.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Search field
                if members.count > 5 {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search members...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }

                // Member list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredMembers) { member in
                        MemberRow(member: member)
                    }
                }
            }
        }
    }
}

struct MemberRow: View {
    let member: GroupMember

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: member.memberType.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.effectiveDisplayName)
                    .font(.body)

                if let secondaryInfo = member.secondaryInfo {
                    Text(secondaryInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                // Show member type badge
                Text(member.memberType.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }

            Spacer()

            // Show enabled/disabled status for users and devices
            if let accountEnabled = member.accountEnabled {
                Image(systemName: accountEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(accountEnabled ? .green : .red)
                    .font(.caption)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Owners Section

struct GroupOwnersSection: View {
    let owners: [GroupOwner]
    let isLoading: Bool
    let isBuiltInTarget: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupSectionHeader(title: "Group Owners", icon: "person.crop.circle")

            if isBuiltInTarget {
                Text("Built-in targets do not have owners.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading owners...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if owners.isEmpty {
                Text("No owners assigned to this group.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Owner list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(owners) { owner in
                        OwnerRow(owner: owner)
                    }
                }
            }
        }
    }
}

struct OwnerRow: View {
    let owner: GroupOwner

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: owner.ownerType.icon)
                .foregroundColor(.purple)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                if let displayName = owner.displayName {
                    Text(displayName)
                        .font(.body)
                }
                if let upn = owner.userPrincipalName {
                    Text(upn)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if let mail = owner.mail {
                    Text(mail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text(owner.ownerType.displayName)
                    .font(.caption2)
                    .foregroundColor(.purple)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Assignments Section

struct GroupAssignmentsSection: View {
    let apps: [Application]
    let isLoading: Bool
    let groupId: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupSectionHeader(title: "Assigned Applications", icon: "app.badge")

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading assignments...")
                        .foregroundColor(.secondary)
                }
                .padding()
            } else if apps.isEmpty {
                Text("No applications assigned to this group.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // App list
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(apps) { app in
                        AssignedAppRow(app: app, groupId: groupId)
                    }
                }
            }
        }
    }
}

struct AssignedAppRow: View {
    let app: Application
    let groupId: String

    private var assignmentIntent: String {
        guard let assignments = app.assignments else { return "Unknown" }

        for assignment in assignments where assignment.target.groupId == groupId {
            return assignment.intent.displayName
        }

        return "Unknown"
    }

    private var intentColor: Color {
        guard let assignments = app.assignments else { return .gray }

        for assignment in assignments where assignment.target.groupId == groupId {
            switch assignment.intent {
            case .required:
                return .red
            case .available:
                return .blue
            case .uninstall:
                return .orange
            case .availableWithoutEnrollment:
                return .purple
            @unknown default:
                return .gray
            }
        }

        return .gray
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: app.appType.icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.displayName)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(app.supportedPlatformsDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(assignmentIntent)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(intentColor)
                }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(intentColor.opacity(0.05))
        .cornerRadius(6)
    }
}

// MARK: - Helper Components

struct GroupSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.headline)
        }
    }
}

struct GroupInfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            Text(value)
                .font(.body)
        }
    }
}
