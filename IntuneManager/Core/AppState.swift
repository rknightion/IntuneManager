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
    @Published var showingPermissionAlert = false
    @Published var permissionErrorDetails: PermissionError?

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case devices = "Devices"
        case applications = "Applications"
        case groups = "Groups"
        case assignments = "Assignments"
        case configuration = "Configuration"
        case reports = "Reports"
        case settings = "Settings"

        var systemImage: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .devices: return "iphone"
            case .applications: return "app.badge"
            case .groups: return "person.3"
            case .assignments: return "checklist"
            case .configuration: return "gearshape.2"
            case .reports: return "chart.bar.doc.horizontal"
            case .settings: return "gear"
            }
        }
    }

    struct PermissionError {
        let operation: String
        let resource: String
        let requiredPermissions: [String]
        let timestamp: Date = Date()

        var formattedDescription: String {
            "Failed to \(operation) due to insufficient permissions. Required permissions: \(requiredPermissions.joined(separator: ", "))"
        }
    }

    func handlePermissionError(operation: String, resource: String) {
        // Map common operations to required permissions
        let requiredPermissions = getRequiredPermissions(for: operation, resource: resource)

        permissionErrorDetails = PermissionError(
            operation: operation,
            resource: resource,
            requiredPermissions: requiredPermissions
        )
        showingPermissionAlert = true

        Logger.shared.error("Permission denied for \(operation) on \(resource). Required: \(requiredPermissions.joined(separator: ", "))", category: .auth)
    }

    private func getRequiredPermissions(for operation: String, resource: String) -> [String] {
        // Map operations to known Graph API permissions
        switch resource {
        case "device", "devices":
            if operation.contains("sync") {
                return ["DeviceManagementManagedDevices.PrivilegedOperations.All"]
            } else if operation.contains("write") || operation.contains("update") {
                return ["DeviceManagementManagedDevices.ReadWrite.All"]
            } else {
                return ["DeviceManagementManagedDevices.Read.All"]
            }
        case "application", "applications":
            if operation.contains("assign") {
                return ["DeviceManagementApps.ReadWrite.All"]
            } else {
                return ["DeviceManagementApps.Read.All"]
            }
        case "group", "groups":
            return ["Group.Read.All", "GroupMember.Read.All"]
        case "assignment", "assignments":
            return ["DeviceManagementApps.ReadWrite.All"]
        case "configuration", "configurations", "profile", "profiles":
            if operation.contains("write") || operation.contains("update") || operation.contains("create") || operation.contains("delete") {
                return ["DeviceManagementConfiguration.ReadWrite.All"]
            } else {
                return ["DeviceManagementConfiguration.Read.All"]
            }
        case "auditLog", "auditLogs":
            return ["DeviceManagementApps.Read.All", "AuditLog.Read.All"]
        default:
            return ["Unknown permission required for \(resource)"]
        }
    }

    func refreshAll() async {
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await DeviceService.shared.fetchDevices(forceRefresh: true)
            _ = try await ApplicationService.shared.fetchApplications(forceRefresh: true)
            _ = try await GroupService.shared.fetchGroups(forceRefresh: true)
            AssignmentService.shared.activeAssignments.removeAll()
            error = nil
        } catch {
            Logger.shared.error("Failed to complete full refresh: \(error)")
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
