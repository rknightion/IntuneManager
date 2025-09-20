import SwiftUI

struct GroupListView: View {
    @StateObject private var groupService = GroupService.shared
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            if groupService.isLoading && groupService.groups.isEmpty {
                ProgressView("Loading groups...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(groupService.searchGroups(query: searchText)) { group in
                    GroupRowView(group: group, isSelected: false) { }
                }
                .searchable(text: $searchText)
            }
        }
        .navigationTitle("Groups")
        .task {
            do {
                _ = try await groupService.fetchGroups()
            } catch {
                Logger.shared.error("Failed to load groups: \(error)")
            }
        }
    }
}
