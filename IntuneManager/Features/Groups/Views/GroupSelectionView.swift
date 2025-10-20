import SwiftUI
import AppKit

struct GroupSelectionView: View {
    @Binding var selectedGroups: Set<DeviceGroup>
    let selectedApplications: Set<Application> // Pass in selected apps to check compatibility
    @ObservedObject private var groupService = GroupService.shared
    @State private var searchText = ""
    @State private var showOnlyDynamic = false
    @State private var showOnlySecurity = true
    @State private var selectedPlatformFilter: Application.DevicePlatform? = nil
    @State private var showOwnerInfo = true
    @State private var selectedGroupForDetail: DeviceGroup?
    @State private var detailViewInitialTab = 0

    @State private var sortOrder = [KeyPathComparator(\DeviceGroup.displayName)]
    @State private var tableSelection = Set<DeviceGroup.ID>()

    // Compute supported platforms from selected apps
    private var supportedPlatforms: Set<Application.DevicePlatform> {
        guard !selectedApplications.isEmpty else { return [] }

        // Find platforms common to ALL selected apps
        let platformSets = selectedApplications.map { $0.supportedPlatforms }
        guard let firstSet = platformSets.first else { return [] }

        return platformSets.dropFirst().reduce(firstSet) { result, platforms in
            result.intersection(platforms)
        }
    }

    private var availableGroups: [DeviceGroup] {
        let custom = DeviceGroup.builtInAssignmentTargets
        // Ensure we don't duplicate built-in targets if the service ever returns them.
        let graphGroups = groupService.groups.filter { !$0.isBuiltInAssignmentTarget }
        return custom + graphGroups
    }

    var filteredGroups: [DeviceGroup] {
        var groups = availableGroups

        if !searchText.isEmpty {
            groups = groups.filter { group in
                group.displayName.localizedCaseInsensitiveContains(searchText) ||
                group.groupDescription?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        if showOnlyDynamic {
            groups = groups.filter { $0.isDynamicGroup }
        }

        if showOnlySecurity {
            groups = groups.filter { $0.securityEnabled }
        }

        // Apply table sort order on macOS
        return groups.sorted(using: sortOrder)
    }

    // Helper function to get icon for group type
    private func groupIcon(for group: DeviceGroup) -> String {
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

    // Get assignment info for a group
    func getAssignmentInfo(_ group: DeviceGroup) -> GroupAssignmentInfo {
        var assignedAppNames: [String] = []

        for app in selectedApplications {
            if let assignments = app.assignments {
                for assignment in assignments {
                    if assignment.target.groupId == group.id {
                        assignedAppNames.append(app.displayName)
                        break // Only count each app once per group
                    }
                }
            }
        }

        return GroupAssignmentInfo(count: assignedAppNames.count, appNames: assignedAppNames)
    }

    struct GroupAssignmentInfo {
        let count: Int
        let appNames: [String]

        var hasAssignments: Bool {
            count > 0
        }

        var badgeColor: Color {
            switch count {
            case 0: return .gray
            case 1...3: return .blue
            default: return .green
            }
        }
    }

    // MARK: - Platform-Specific Views

    private var groupTableView: some View {
        Table(filteredGroups, selection: $tableSelection) {
            TableColumn("Name") { group in
                HStack(spacing: 8) {
                    Image(systemName: groupIcon(for: group))
                        .foregroundColor(.accentColor)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.displayName)
                            .font(.body)
                        if let desc = group.groupDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .width(min: 200, ideal: 300, max: 500)

            TableColumn("Type") { group in
                HStack(spacing: 4) {
                    if group.securityEnabled {
                        GroupBadge(label: "Sec", icon: "lock.shield", color: .green)
                    }
                    if group.isDynamicGroup {
                        GroupBadge(label: "Dyn", icon: "arrow.triangle.2.circlepath", color: .blue)
                    }
                    if group.mailEnabled {
                        GroupBadge(label: "M365", icon: "person.3", color: .purple)
                    }
                    if group.onPremisesSyncEnabled == true {
                        GroupBadge(label: "Sync", icon: "arrow.triangle.branch", color: .orange)
                    }
                }
            }
            .width(min: 100, ideal: 150)

            TableColumn("Members") { group in
                if let count = group.memberCount {
                    Text("\(count)")
                        .foregroundColor(.secondary)
                } else if group.isBuiltInAssignmentTarget {
                    Text("—")
                        .foregroundColor(.secondary)
                } else {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .width(80)

            TableColumn("Owners") { group in
                if let owners = group.owners, !owners.isEmpty {
                    Text("\(owners.count)")
                        .foregroundColor(.purple)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(80)

            TableColumn("Assignments") { group in
                let info = getAssignmentInfo(group)
                if info.count > 0 {
                    Text("\(info.count)")
                        .foregroundColor(info.badgeColor)
                } else {
                    Text("—")
                        .foregroundColor(.secondary)
                }
            }
            .width(100)

            TableColumn("Actions") { group in
                Button {
                    selectedGroupForDetail = group
                    detailViewInitialTab = 0
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
            }
            .width(60)
        }
        .contextMenu(forSelectionType: DeviceGroup.ID.self) { items in
            if items.count == 1, let groupId = items.first,
               let group = filteredGroups.first(where: { $0.id == groupId }) {
                Button {
                    selectedGroupForDetail = group
                    detailViewInitialTab = 0
                } label: {
                    Label("View Details", systemImage: "info.circle")
                }

                Button {
                    selectedGroupForDetail = group
                    detailViewInitialTab = 1
                } label: {
                    Label("View Members", systemImage: "person.2")
                }

                Button {
                    selectedGroupForDetail = group
                    detailViewInitialTab = 2
                } label: {
                    Label("View Owners", systemImage: "person.crop.circle")
                }

                Button {
                    selectedGroupForDetail = group
                    detailViewInitialTab = 3
                } label: {
                    Label("View Assignments", systemImage: "app.badge")
                }

                Divider()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(group.id, forType: .string)
                } label: {
                    Label("Copy Group ID", systemImage: "doc.on.doc")
                }
            }
        }
        .onChange(of: tableSelection) {
            // Sync table selection to selectedGroups
            selectedGroups = Set(filteredGroups.filter { tableSelection.contains($0.id) })
        }
        .onChange(of: selectedGroups) {
            // Sync selectedGroups to table selection
            tableSelection = Set(selectedGroups.map { $0.id })
        }
    }
    // MARK: - Body

    var body: some View {
        VStack {
            // Platform compatibility warning
            if !supportedPlatforms.isEmpty {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Selected apps support: \(supportedPlatforms.map { $0.displayName }.sorted().joined(separator: ", "))")
                        .font(.caption)
                    Spacer()
                    if supportedPlatforms.count > 1 {
                        Picker("Target Platform", selection: $selectedPlatformFilter) {
                            Text("All Platforms").tag(Application.DevicePlatform?.none)
                            ForEach(Array(supportedPlatforms.sorted { $0.rawValue < $1.rawValue }), id: \.self) { platform in
                                Label(platform.displayName, systemImage: platform.icon)
                                    .tag(Application.DevicePlatform?.some(platform))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }

            // Toolbar
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search groups...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)

                Toggle("Dynamic Only", isOn: $showOnlyDynamic)
                Toggle("Security Groups", isOn: $showOnlySecurity)
                Toggle("Show Owners", isOn: $showOwnerInfo)

                Spacer()

                Text("\(selectedGroups.count) selected")
                    .foregroundColor(.secondary)

                Button("Select All") {
                    selectedGroups = Set(filteredGroups)
                }

                Button("Clear") {
                    selectedGroups.removeAll()
                }
                .disabled(selectedGroups.isEmpty)
            }
            .padding()

            groupTableView
        }
        .task {
            if groupService.groups.isEmpty {
                do {
                    _ = try await groupService.fetchGroups()

                    // Fetch owners asynchronously after groups are loaded
                    if showOwnerInfo {
                        await groupService.fetchOwnersForGroups(groupService.groups)
                    }
                } catch {
                    Logger.shared.error("Failed to load groups: \(error)")
                }
            }
        }
        .sheet(item: $selectedGroupForDetail) { group in
            GroupDetailView(group: group, initialTab: detailViewInitialTab)
                .frame(minWidth: 600, minHeight: 500)
        }
    }
}

struct GroupRowView: View {
    let group: DeviceGroup
    let isSelected: Bool
    let onToggle: () -> Void
    var assignmentInfo: GroupSelectionView.GroupAssignmentInfo = GroupSelectionView.GroupAssignmentInfo(count: 0, appNames: [])
    var showOwnerInfo: Bool = true
    var onShowDetail: ((DeviceGroup, Int) -> Void)?

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(group.displayName)
                        .font(.system(.body, design: .default))
                        .lineLimit(1)

                    if assignmentInfo.hasAssignments {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                            Text("\(assignmentInfo.count) app\(assignmentInfo.count == 1 ? "" : "s") assigned")
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(assignmentInfo.badgeColor)
                        .cornerRadius(4)
                        .help(assignmentInfo.appNames.joined(separator: "\n"))
                    }
                }

                HStack(spacing: 6) {
                    // Group type badges
                    if group.securityEnabled {
                        GroupBadge(label: "Security", icon: "lock.shield", color: .green)
                    }

                    if group.mailEnabled && !group.securityEnabled {
                        GroupBadge(label: "Distribution", icon: "envelope", color: .purple)
                    }

                    if group.groupTypes?.contains("Unified") == true || group.mailEnabled {
                        GroupBadge(label: "M365", icon: "person.3", color: .purple)
                    }

                    if group.isDynamicGroup {
                        GroupBadge(label: "Dynamic", icon: "arrow.triangle.2.circlepath", color: .blue)
                    }

                    // On-premises sync status
                    if group.onPremisesSyncEnabled == true {
                        GroupBadge(label: "Synced", icon: "arrow.triangle.branch", color: .orange)
                    }

                    // Owner information
                    if showOwnerInfo && group.hasOwners {
                        if let owners = group.owners {
                            if owners.count == 1, let ownerName = owners.first?.displayName {
                                GroupBadge(label: "Owner: \(ownerName)", icon: "person.crop.circle", color: .purple)
                                    .help(ownerName)
                            } else if owners.count > 1 {
                                GroupBadge(label: "\(owners.count) owners", icon: "person.2.crop.square.stack", color: .purple)
                                    .help(owners.compactMap { $0.displayName }.joined(separator: "\n"))
                            }
                        }
                    }

                    // Member count - always visible
                    if group.isBuiltInAssignmentTarget {
                        Text("• Tenant-wide")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if let memberCount = group.memberCount {
                                Text("\(memberCount) members")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                HStack(spacing: 4) {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                    Text("Loading...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Spacer()

            if group.membershipRuleProcessingState == .evaluating {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.gray.opacity(0.05))
        .cornerRadius(8)
        .onTapGesture {
            onToggle()
        }
        .contextMenu {
            // View Details - General tab
            Button {
                onShowDetail?(group, 0)
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            // View Members - Members tab
            Button {
                onShowDetail?(group, 1)
            } label: {
                Label("View Members", systemImage: "person.2")
            }

            // View Owners - Owners tab
            Button {
                onShowDetail?(group, 2)
            } label: {
                Label("View Owners", systemImage: "person.crop.circle")
            }

            // View Assignments - Assignments tab
            Button {
                onShowDetail?(group, 3)
            } label: {
                Label("View Assignments", systemImage: "app.badge")
            }

            Divider()

            // Copy Group ID
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(group.id, forType: .string)
            } label: {
                Label("Copy Group ID", systemImage: "doc.on.doc")
            }
        }
    }
}

// MARK: - Group Badge Component
struct GroupBadge: View {
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .cornerRadius(4)
    }
}
