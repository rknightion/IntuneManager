import Foundation
import KeychainAccess
import Combine

/// Manages secure storage and retrieval of authentication credentials
@MainActor
class CredentialManager: ObservableObject {
    static let shared = CredentialManager()

    @Published var isConfigured: Bool = false
    @Published var configuration: AppConfiguration?

    private let keychain: Keychain
    private let keychainServiceIdentifier = "com.intunemanager.credentials"
    private let configKey = "app_configuration"

    // Keys for secure storage
    private enum KeychainKeys {
        static let clientId = "client_id"
        static let tenantId = "tenant_id"
        static let clientSecret = "client_secret"
        static let redirectUri = "redirect_uri"
        static let configuredDate = "configured_date"
        static let lastValidatedDate = "last_validated_date"
    }

    private init() {
        // Initialize keychain with access group for shared access
        #if os(iOS)
        self.keychain = Keychain(service: keychainServiceIdentifier)
            .accessibility(.whenUnlockedThisDeviceOnly)
            .synchronizable(false)
        #else
        self.keychain = Keychain(service: keychainServiceIdentifier)
            .synchronizable(false)
        #endif

        loadConfiguration()
    }

    // MARK: - Configuration Management

    /// Checks if the app has been configured with credentials
    func checkConfiguration() -> Bool {
        return configuration != nil && configuration!.isValid
    }

    /// Loads configuration from keychain
    private func loadConfiguration() {
        do {
            guard let clientId = try keychain.getString(KeychainKeys.clientId),
                  let tenantId = try keychain.getString(KeychainKeys.tenantId) else {
                isConfigured = false
                return
            }

            // Client secret is optional for public clients
            let clientSecret = try keychain.getString(KeychainKeys.clientSecret)
            let redirectUri = try keychain.getString(KeychainKeys.redirectUri) ?? generateDefaultRedirectUri()

            configuration = AppConfiguration(
                clientId: clientId,
                tenantId: tenantId,
                clientSecret: clientSecret,
                redirectUri: redirectUri
            )

            isConfigured = true

            Logger.shared.info("Configuration loaded successfully")
        } catch {
            Logger.shared.error("Failed to load configuration: \(error)")
            isConfigured = false
        }
    }

    /// Saves configuration to keychain
    func saveConfiguration(_ config: AppConfiguration) async throws {
        // Validate configuration before saving
        guard config.isValid else {
            throw CredentialError.invalidConfiguration
        }

        do {
            // Store credentials securely in keychain
            try keychain.set(config.clientId, key: KeychainKeys.clientId)
            try keychain.set(config.tenantId, key: KeychainKeys.tenantId)

            if let secret = config.clientSecret {
                try keychain.set(secret, key: KeychainKeys.clientSecret)
            }

            try keychain.set(config.redirectUri, key: KeychainKeys.redirectUri)
            try keychain.set(Date().iso8601String, key: KeychainKeys.configuredDate)

            self.configuration = config
            self.isConfigured = true

            // Save to UserDefaults for non-sensitive data
            UserDefaults.standard.set(true, forKey: "app_configured")
            UserDefaults.standard.set(config.tenantId, forKey: "tenant_id_display")

            Logger.shared.info("Configuration saved successfully")
        } catch {
            Logger.shared.error("Failed to save configuration: \(error)")
            throw CredentialError.saveFailed(error)
        }
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

        if updates.updateSecret {
            config.clientSecret = updates.clientSecret
        }

        if let redirectUri = updates.redirectUri {
            config.redirectUri = redirectUri
        }

        try await saveConfiguration(config)
    }

    /// Clears all stored credentials
    func clearConfiguration() async throws {
        do {
            try keychain.removeAll()

            configuration = nil
            isConfigured = false

            UserDefaults.standard.removeObject(forKey: "app_configured")
            UserDefaults.standard.removeObject(forKey: "tenant_id_display")

            Logger.shared.info("Configuration cleared")
        } catch {
            Logger.shared.error("Failed to clear configuration: \(error)")
            throw CredentialError.clearFailed(error)
        }
    }

    /// Validates stored credentials
    func validateConfiguration() async -> Bool {
        guard let config = configuration else {
            return false
        }

        // Basic validation
        guard config.isValid else {
            return false
        }

        // Store validation timestamp
        try? keychain.set(Date().iso8601String, key: KeychainKeys.lastValidatedDate)

        return true
    }

    /// Generates default redirect URI based on bundle identifier
    private func generateDefaultRedirectUri() -> String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.intunemanager"
        return "msauth.\(bundleId)://auth"
    }

    // MARK: - Token Management

    /// Stores access token securely
    func storeAccessToken(_ token: String, expiresIn: TimeInterval) throws {
        let expirationDate = Date().addingTimeInterval(expiresIn)
        try keychain.set(token, key: "access_token")
        try keychain.set(expirationDate.iso8601String, key: "token_expiration")
    }

    /// Retrieves access token if valid
    func getAccessToken() -> String? {
        do {
            guard let token = try keychain.getString("access_token"),
                  let expirationString = try keychain.getString("token_expiration"),
                  let expirationDate = Date.fromISO8601String(expirationString) else {
                return nil
            }

            // Check if token is still valid
            if expirationDate > Date() {
                return token
            } else {
                // Token expired, clear it
                try? keychain.remove("access_token")
                try? keychain.remove("token_expiration")
                return nil
            }
        } catch {
            Logger.shared.error("Failed to retrieve access token: \(error)")
            return nil
        }
    }

    /// Clears stored tokens
    func clearTokens() {
        try? keychain.remove("access_token")
        try? keychain.remove("token_expiration")
        try? keychain.remove("refresh_token")
    }
}

// MARK: - Supporting Types

struct AppConfiguration: Codable {
    var clientId: String
    var tenantId: String
    var clientSecret: String?
    var redirectUri: String
    var authority: String {
        return "https://login.microsoftonline.com/\(tenantId)"
    }

    var isValid: Bool {
        !clientId.isEmpty && !tenantId.isEmpty && !redirectUri.isEmpty
    }

    /// Determines if this is a public client (no secret) or confidential client
    var isPublicClient: Bool {
        return clientSecret == nil || clientSecret!.isEmpty
    }
}

struct ConfigurationUpdate {
    var clientId: String?
    var tenantId: String?
    var clientSecret: String?
    var updateSecret: Bool = false
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
