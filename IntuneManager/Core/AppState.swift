import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .dashboard
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingAbout = false
    @Published var preferredColorScheme: ColorScheme? = nil

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case devices = "Devices"
        case applications = "Applications"
        case groups = "Groups"
        case assignments = "Assignments"
        case reports = "Reports"
        case settings = "Settings"

        var systemImage: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .devices: return "iphone"
            case .applications: return "app.badge"
            case .groups: return "person.3"
            case .assignments: return "checklist"
            case .reports: return "chart.bar.doc.horizontal"
            case .settings: return "gear"
            }
        }
    }

    func syncAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await DeviceService.shared.fetchDevices(forceRefresh: true)
            _ = try await ApplicationService.shared.fetchApplications(forceRefresh: true)
            _ = try await GroupService.shared.fetchGroups(forceRefresh: true)
            AssignmentService.shared.activeAssignments.removeAll()
            error = nil
        } catch {
            Logger.shared.error("Failed to complete full sync: \(error)")
            self.error = error
        }
    }

    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await DeviceService.shared.fetchDevices()
            _ = try await ApplicationService.shared.fetchApplications()
            _ = try await GroupService.shared.fetchGroups()
        } catch {
            Logger.shared.error("Failed to load initial data: \(error)")
            self.error = error
        }
    }
}
