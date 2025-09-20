import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .dashboard
    @Published var isLoading = false
    @Published var error: Error?

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case devices = "Devices"
        case applications = "Applications"
        case groups = "Groups"
        case assignments = "Assignments"
        case settings = "Settings"

        var systemImage: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .devices: return "iphone"
            case .applications: return "app.badge"
            case .groups: return "person.3"
            case .assignments: return "checklist"
            case .settings: return "gear"
            }
        }
    }

    func syncAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Implement sync logic here
        } catch {
            self.error = error
        }
    }
}