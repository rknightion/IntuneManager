import SwiftUI

struct GroupSelectionView: View {
    @Binding var selectedGroups: Set<DeviceGroup>
    @StateObject private var groupService = GroupService.shared
    @State private var searchText = ""
    @State private var showOnlyDynamic = false
    @State private var showOnlySecurity = true

    var filteredGroups: [DeviceGroup] {
        var groups = groupService.groups

        if !searchText.isEmpty {
            groups = groups.filter { group in
                group.displayName.localizedCaseInsensitiveContains(searchText) ||
                group.description?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        if showOnlyDynamic {
            groups = groups.filter { $0.isDynamicGroup }
        }

        if showOnlySecurity {
            groups = groups.filter { $0.securityEnabled }
        }

        return groups.sorted { $0.displayName < $1.displayName }
    }

    var body: some View {
        VStack {
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

            // Group List
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredGroups) { group in
                        GroupRowView(
                            group: group,
                            isSelected: selectedGroups.contains(group),
                            onToggle: {
                                if selectedGroups.contains(group) {
                                    selectedGroups.remove(group)
                                } else {
                                    selectedGroups.insert(group)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .task {
            if groupService.groups.isEmpty {
                try? await groupService.fetchGroups()
            }
        }
    }
}

struct GroupRowView: View {
    let group: DeviceGroup
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.system(.body, design: .default))
                    .lineLimit(1)

                HStack {
                    if group.isDynamicGroup {
                        Label("Dynamic", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }

                    if group.securityEnabled {
                        Label("Security", systemImage: "lock.shield")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    if let memberCount = group.memberCount {
                        Text("• \(memberCount) members")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
    }
}