import Foundation
import MSAL

struct MSALConfiguration {
    static let current = MSALConfiguration()

    let clientId: String
    let tenantId: String
    let redirectUri: String
    let authority: MSALAuthority
    let scopes: [String]
    let bundleId: String

    private init() {
        // Load from Info.plist or configuration file
        // For production, these should be stored securely
        self.clientId = ProcessInfo.processInfo.environment["INTUNE_CLIENT_ID"] ?? "YOUR_CLIENT_ID_HERE"
        self.tenantId = ProcessInfo.processInfo.environment["INTUNE_TENANT_ID"] ?? "common"

        self.bundleId = Bundle.main.bundleIdentifier ?? "com.intunemanager"

        #if os(iOS)
        self.redirectUri = "msauth.\(bundleId)://auth"
        #else
        self.redirectUri = "msauth.\(bundleId)://auth"
        #endif

        // Initialize authority
        let authorityURL = "https://login.microsoftonline.com/\(tenantId)"
        self.authority = try! MSALAuthority(url: URL(string: authorityURL)!)

        // Required scopes for Intune management
        self.scopes = [
            "https://graph.microsoft.com/User.Read",
            "https://graph.microsoft.com/DeviceManagementManagedDevices.Read.All",
            "https://graph.microsoft.com/DeviceManagementManagedDevices.ReadWrite.All",
            "https://graph.microsoft.com/DeviceManagementApps.Read.All",
            "https://graph.microsoft.com/DeviceManagementApps.ReadWrite.All",
            "https://graph.microsoft.com/DeviceManagementConfiguration.Read.All",
            "https://graph.microsoft.com/DeviceManagementConfiguration.ReadWrite.All",
            "https://graph.microsoft.com/DeviceManagementRBAC.Read.All",
            "https://graph.microsoft.com/Group.Read.All",
            "https://graph.microsoft.com/GroupMember.Read.All"
        ]
    }

    static func validate() -> Bool {
        let config = MSALConfiguration.current
        return config.clientId != "YOUR_CLIENT_ID_HERE" &&
               !config.clientId.isEmpty
    }
}