import Foundation
import Combine

/// Service to check and validate Microsoft Graph API permissions at startup
@MainActor
final class PermissionCheckService: ObservableObject {
    static let shared = PermissionCheckService()

    @Published var missingPermissions: [GraphPermission] = []
    @Published var hasCheckedPermissions = false
    @Published var lastCheckDate: Date?

    private let apiClient = GraphAPIClient.shared

    private init() {}

    // MARK: - Required Permissions

    /// All Graph API permissions required by the app
    /// IMPORTANT: When adding new features that require Graph permissions,
    /// you MUST add the required permissions to this array
    static let requiredPermissions: [GraphPermission] = [
        // User Profile
        GraphPermission(
            scope: "User.Read",
            description: "Read user profile information",
            features: ["Authentication", "User Display"]
        ),

        // Device Management - Read
        GraphPermission(
            scope: "DeviceManagementManagedDevices.Read.All",
            description: "Read managed devices",
            features: ["Device List", "Device Details", "Dashboard"]
        ),

        // Device Management - Write
        GraphPermission(
            scope: "DeviceManagementManagedDevices.ReadWrite.All",
            description: "Read and write managed devices",
            features: ["Device Management", "Device Updates"]
        ),

        // Device Management - Privileged Operations
        GraphPermission(
            scope: "DeviceManagementManagedDevices.PrivilegedOperations.All",
            description: "Perform privileged operations on managed devices",
            features: ["Device Sync", "Remote Actions"]
        ),

        // App Management - Read
        GraphPermission(
            scope: "DeviceManagementApps.Read.All",
            description: "Read managed apps and assignments",
            features: ["Application List", "Application Details", "Audit Logs"]
        ),

        // App Management - Write
        GraphPermission(
            scope: "DeviceManagementApps.ReadWrite.All",
            description: "Read and write app assignments",
            features: ["Bulk Assignment", "Assignment Management", "Application Updates", "Application Creation"]
        ),

        // Group Management
        GraphPermission(
            scope: "Group.Read.All",
            description: "Read all groups",
            features: ["Group List", "Group Details", "Group Selection"]
        ),

        // Group Members
        GraphPermission(
            scope: "GroupMember.Read.All",
            description: "Read group memberships",
            features: ["Group Members", "Group Owners", "Assignment Targeting"]
        ),

        // Configuration - Read
        GraphPermission(
            scope: "DeviceManagementConfiguration.Read.All",
            description: "Read device configurations and profiles",
            features: ["Configuration Profiles", "Profile Templates", "Compliance Policies"]
        ),

        // Configuration - Write
        GraphPermission(
            scope: "DeviceManagementConfiguration.ReadWrite.All",
            description: "Read and write device configurations",
            features: ["Configuration Management", "Profile Creation", "Profile Updates", "MobileConfig Import"]
        ),

        // Audit Logs
        GraphPermission(
            scope: "AuditLog.Read.All",
            description: "Read audit log data",
            features: ["Audit Log Viewer", "Reports"]
        ),
    ]

    // MARK: - Permission Check

    /// Checks if all required permissions are granted
    /// This queries the /me endpoint to get the currently granted scopes
    func checkPermissions() async {
        Logger.shared.info("Starting permission check...", category: .auth)
        hasCheckedPermissions = false
        missingPermissions.removeAll()

        do {
            // Get the current access token to inspect its scopes
            let token = try await AuthManagerV2.shared.getAccessToken()

            // Decode JWT to get granted scopes
            let grantedScopes = extractScopesFromToken(token)

            Logger.shared.info("Granted scopes: \(grantedScopes.joined(separator: ", "))", category: .auth)

            // Check each required permission
            for permission in Self.requiredPermissions {
                let hasPermission = grantedScopes.contains { grantedScope in
                    // Match exact scope or check if it's a subset
                    grantedScope == permission.scope ||
                    grantedScope == "https://graph.microsoft.com/\(permission.scope)"
                }

                if !hasPermission {
                    missingPermissions.append(permission)
                    Logger.shared.warning("Missing permission: \(permission.scope)", category: .auth)
                }
            }

            lastCheckDate = Date()
            hasCheckedPermissions = true

            if missingPermissions.isEmpty {
                Logger.shared.info("✓ All required permissions are granted", category: .auth)
            } else {
                Logger.shared.warning("⚠️ Missing \(missingPermissions.count) required permissions", category: .auth)
            }

        } catch {
            Logger.shared.error("Failed to check permissions: \(error.localizedDescription)", category: .auth)
            hasCheckedPermissions = true
        }
    }

    // MARK: - Helper Methods

    /// Extracts scopes from a JWT access token
    private func extractScopesFromToken(_ token: String) -> [String] {
        // JWT tokens have three parts separated by dots
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            Logger.shared.error("Invalid JWT token format", category: .auth)
            return []
        }

        // Decode the payload (second part)
        let payload = parts[1]

        // Add padding if needed for base64 decoding
        var base64 = payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Logger.shared.error("Failed to decode JWT payload", category: .auth)
            return []
        }

        // Extract scopes - they can be in 'scp' (delegated) or 'roles' (application) claims
        var scopes: [String] = []

        if let scp = json["scp"] as? String {
            scopes.append(contentsOf: scp.components(separatedBy: " "))
        }

        if let roles = json["roles"] as? [String] {
            scopes.append(contentsOf: roles)
        }

        return scopes
    }

    /// Gets missing permissions grouped by category
    var missingPermissionsByCategory: [String: [GraphPermission]] {
        Dictionary(grouping: missingPermissions) { permission in
            if permission.scope.contains("Device") {
                return "Device Management"
            } else if permission.scope.contains("Apps") {
                return "Application Management"
            } else if permission.scope.contains("Group") {
                return "Group Management"
            } else if permission.scope.contains("Configuration") {
                return "Configuration Management"
            } else if permission.scope.contains("AuditLog") {
                return "Audit & Reporting"
            } else {
                return "Other"
            }
        }
    }

    /// Generates a summary message about missing permissions
    var missingSummary: String {
        guard !missingPermissions.isEmpty else {
            return "All required permissions are granted."
        }

        let categories = missingPermissionsByCategory
        var summary = "Missing \(missingPermissions.count) required permission(s):\n\n"

        for (category, permissions) in categories.sorted(by: { $0.key < $1.key }) {
            summary += "\(category):\n"
            for permission in permissions {
                summary += "  • \(permission.scope)\n"
                summary += "    Used by: \(permission.features.joined(separator: ", "))\n"
            }
            summary += "\n"
        }

        summary += "Please contact your Azure AD administrator to grant these permissions."

        return summary
    }
}

// MARK: - Supporting Types

struct GraphPermission: Identifiable, Codable, Hashable {
    let id = UUID()
    let scope: String
    let description: String
    let features: [String]

    enum CodingKeys: String, CodingKey {
        case scope, description, features
    }
}
