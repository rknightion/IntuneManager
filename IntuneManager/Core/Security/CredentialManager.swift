import Foundation
import Combine

/// Manages storage and retrieval of application configuration
/// Note: MSAL handles all token storage securely in the keychain automatically
@MainActor
class CredentialManager: ObservableObject {
    static let shared = CredentialManager()

    @Published var isConfigured: Bool = false
    @Published var configuration: AppConfiguration?

    // UserDefaults keys - these aren't secrets, just configuration
    private enum ConfigKeys {
        static let clientId = "app.config.clientId"
        static let tenantId = "app.config.tenantId"
        static let redirectUri = "app.config.redirectUri"
        static let configuredDate = "app.config.configuredDate"
        static let isConfigured = "app.config.isConfigured"
    }

    private let userDefaults = UserDefaults.standard

    private init() {
        loadConfiguration()
    }

    // MARK: - Configuration Management

    /// Checks if the app has been configured with credentials
    func checkConfiguration() -> Bool {
        return configuration != nil && configuration!.isValid
    }

    /// Loads configuration from UserDefaults
    /// Note: Client ID and Tenant ID are not secrets - they're public information
    /// MSAL handles all actual authentication tokens securely
    private func loadConfiguration() {
        guard userDefaults.bool(forKey: ConfigKeys.isConfigured),
              let clientId = userDefaults.string(forKey: ConfigKeys.clientId),
              let tenantId = userDefaults.string(forKey: ConfigKeys.tenantId) else {
            isConfigured = false
            return
        }

        let redirectUri = userDefaults.string(forKey: ConfigKeys.redirectUri) ?? generateDefaultRedirectUri()

        configuration = AppConfiguration(
            clientId: clientId,
            tenantId: tenantId,
            clientSecret: nil, // Native apps don't use client secrets
            redirectUri: redirectUri
        )

        isConfigured = true
        Logger.shared.info("Configuration loaded successfully")
    }

    /// Saves configuration to UserDefaults
    /// Note: Only non-sensitive configuration is stored. MSAL handles all tokens.
    func saveConfiguration(_ config: AppConfiguration) async throws {
        // Validate configuration before saving
        guard config.isValid else {
            throw CredentialError.invalidConfiguration
        }

        // Store configuration in UserDefaults (these aren't secrets)
        userDefaults.set(config.clientId, forKey: ConfigKeys.clientId)
        userDefaults.set(config.tenantId, forKey: ConfigKeys.tenantId)
        userDefaults.set(config.redirectUri, forKey: ConfigKeys.redirectUri)
        userDefaults.set(Date().iso8601String, forKey: ConfigKeys.configuredDate)
        userDefaults.set(true, forKey: ConfigKeys.isConfigured)

        self.configuration = config
        self.isConfigured = true

        Logger.shared.info("Configuration saved successfully")
    }

    /// Updates existing configuration
    func updateConfiguration(_ updates: ConfigurationUpdate) async throws {
        guard var config = configuration else {
            throw CredentialError.notConfigured
        }

        if let clientId = updates.clientId {
            config.clientId = clientId
        }

        if let tenantId = updates.tenantId {
            config.tenantId = tenantId
        }

        if let redirectUri = updates.redirectUri {
            config.redirectUri = redirectUri
        }

        try await saveConfiguration(config)
    }

    /// Clears all stored configuration
    /// Note: This doesn't clear MSAL tokens - use AuthManager.signOut() for that
    func clearConfiguration() async throws {
        userDefaults.removeObject(forKey: ConfigKeys.clientId)
        userDefaults.removeObject(forKey: ConfigKeys.tenantId)
        userDefaults.removeObject(forKey: ConfigKeys.redirectUri)
        userDefaults.removeObject(forKey: ConfigKeys.configuredDate)
        userDefaults.removeObject(forKey: ConfigKeys.isConfigured)

        configuration = nil
        isConfigured = false

        Logger.shared.info("Configuration cleared")
    }

    /// Validates stored configuration
    func validateConfiguration() async -> Bool {
        guard let config = configuration else {
            return false
        }

        return config.isValid
    }

    /// Generates default redirect URI based on bundle identifier
    private func generateDefaultRedirectUri() -> String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.intunemanager"
        return "msauth.\(bundleId)://auth"
    }
}

// MARK: - Supporting Types

struct AppConfiguration: Codable {
    var clientId: String
    var tenantId: String
    var clientSecret: String? // Always nil for native apps using PKCE
    var redirectUri: String
    var authority: String {
        return "https://login.microsoftonline.com/\(tenantId)"
    }

    var isValid: Bool {
        !clientId.isEmpty && !tenantId.isEmpty && !redirectUri.isEmpty
    }

    /// Native apps are always public clients (no secret)
    var isPublicClient: Bool {
        return true
    }
}

struct ConfigurationUpdate {
    var clientId: String?
    var tenantId: String?
    var clientSecret: String? // Kept for API compatibility but always nil
    var updateSecret: Bool = false // Ignored for native apps
    var redirectUri: String?
}

enum CredentialError: LocalizedError {
    case invalidConfiguration
    case notConfigured
    case saveFailed(Error)
    case clearFailed(Error)
    case tokenExpired
    case validationFailed

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Invalid configuration. Please check your credentials."
        case .notConfigured:
            return "App is not configured. Please enter your credentials."
        case .saveFailed(let error):
            return "Failed to save configuration: \(error.localizedDescription)"
        case .clearFailed(let error):
            return "Failed to clear configuration: \(error.localizedDescription)"
        case .tokenExpired:
            return "Authentication token has expired. Please sign in again."
        case .validationFailed:
            return "Credential validation failed. Please check your configuration."
        }
    }
}

// MARK: - Date Extensions

extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }

    static func fromISO8601String(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: string)
    }
}