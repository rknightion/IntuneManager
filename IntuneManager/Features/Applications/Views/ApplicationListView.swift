import SwiftUI

struct ApplicationListView: View {
    @StateObject private var appService = ApplicationService.shared
    @State private var searchText = ""
    
    var body: some View {
        VStack {
            if appService.isLoading && appService.applications.isEmpty {
                ProgressView("Loading applications...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(appService.searchApplications(query: searchText)) { app in
                    ApplicationRowView(application: app, isSelected: false) { }
                }
                .searchable(text: $searchText)
            }
        }
        .navigationTitle("Applications")
        .onAppear {
            Task {
                do {
                    _ = try await appService.fetchApplications()
                } catch {
                    Logger.shared.error("Failed to load applications: \(error)")
                }
            }
        }
    }
}
