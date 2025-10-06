import SwiftUI

struct GroupListView: View {
    @ObservedObject private var groupService = GroupService.shared
    @State private var searchText = ""
    @State private var selectedGroup: DeviceGroup?
    @State private var selectedGroupForDetail: DeviceGroup?
    @State private var detailViewInitialTab = 0

    var body: some View {
        VStack {
            if groupService.isLoading && groupService.groups.isEmpty {
                ProgressView("Loading groups...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(groupService.searchGroups(query: searchText), selection: $selectedGroup) { group in
                    GroupRowView(
                        group: group,
                        isSelected: selectedGroup?.id == group.id,
                        onToggle: {
                            selectedGroup = group
                        },
                        onShowDetail: { group, tab in
                            selectedGroupForDetail = group
                            detailViewInitialTab = tab
                        }
                    )
                }
                .searchable(text: $searchText)
            }
        }
        .navigationTitle("Groups")
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if let group = selectedGroup {
                    Button {
                        selectedGroupForDetail = group
                        detailViewInitialTab = 0
                    } label: {
                        Label("View Details", systemImage: "info.circle")
                    }
                    .help("View group details")

                    Button {
                        selectedGroupForDetail = group
                        detailViewInitialTab = 1
                    } label: {
                        Label("View Members", systemImage: "person.2")
                    }
                    .help("View group members")

                    Button {
                        selectedGroupForDetail = group
                        detailViewInitialTab = 2
                    } label: {
                        Label("View Owners", systemImage: "person.crop.circle")
                    }
                    .help("View group owners")

                    Button {
                        selectedGroupForDetail = group
                        detailViewInitialTab = 3
                    } label: {
                        Label("View Assignments", systemImage: "app.badge")
                    }
                    .help("View group assignments")
                }
            }
        }
        .sheet(item: $selectedGroupForDetail) { group in
            GroupDetailView(group: group, initialTab: detailViewInitialTab)
                #if os(macOS)
                .frame(minWidth: 600, minHeight: 500)
                #endif
        }
        .task {
            do {
                _ = try await groupService.fetchGroups()
            } catch {
                Logger.shared.error("Failed to load groups: \(error)")
            }
        }
    }
}
