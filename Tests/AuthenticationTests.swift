import XCTest
@testable import IntuneManager

/// Comprehensive tests for MSAL v2 authentication flow and credential management
class AuthenticationTests: XCTestCase {

    var credentialManager: CredentialManager!
    var authManager: AuthManagerV2!

    override func setUp() {
        super.setUp()
        credentialManager = CredentialManager.shared
        authManager = AuthManagerV2.shared
    }

    override func tearDown() {
        // Clean up test data
        Task {
            try? await credentialManager.clearConfiguration()
        }
        super.tearDown()
    }

    // MARK: - Credential Manager Tests

    func testSaveConfiguration() async throws {
        let config = AppConfiguration(
            clientId: "test-client-id",
            tenantId: "test-tenant-id",
            clientSecret: nil,
            redirectUri: "msauth.com.test://auth"
        )

        try await credentialManager.saveConfiguration(config)

        XCTAssertTrue(credentialManager.isConfigured)
        XCTAssertNotNil(credentialManager.configuration)
        XCTAssertEqual(credentialManager.configuration?.clientId, "test-client-id")
        XCTAssertEqual(credentialManager.configuration?.tenantId, "test-tenant-id")
        XCTAssertTrue(credentialManager.configuration?.isPublicClient ?? false)
    }

    func testSaveConfigurationWithSecret() async throws {
        let config = AppConfiguration(
            clientId: "test-client-id",
            tenantId: "test-tenant-id",
            clientSecret: "test-secret",
            redirectUri: "msauth.com.test://auth"
        )

        try await credentialManager.saveConfiguration(config)

        XCTAssertTrue(credentialManager.isConfigured)
        XCTAssertNotNil(credentialManager.configuration)
        XCTAssertEqual(credentialManager.configuration?.clientSecret, "test-secret")
        XCTAssertFalse(credentialManager.configuration?.isPublicClient ?? true)
    }

    func testInvalidConfiguration() async {
        let config = AppConfiguration(
            clientId: "",  // Invalid - empty
            tenantId: "test-tenant-id",
            clientSecret: nil,
            redirectUri: "msauth.com.test://auth"
        )

        do {
            try await credentialManager.saveConfiguration(config)
            XCTFail("Should have thrown invalid configuration error")
        } catch {
            XCTAssertTrue(error is CredentialError)
        }
    }

    func testClearConfiguration() async throws {
        // First save a configuration
        let config = AppConfiguration(
            clientId: "test-client-id",
            tenantId: "test-tenant-id",
            clientSecret: nil,
            redirectUri: "msauth.com.test://auth"
        )
        try await credentialManager.saveConfiguration(config)

        // Then clear it
        try await credentialManager.clearConfiguration()

        XCTAssertFalse(credentialManager.isConfigured)
        XCTAssertNil(credentialManager.configuration)
    }

    func testTokenStorage() throws {
        let testToken = "test-access-token"
        let expiresIn: TimeInterval = 3600 // 1 hour

        try credentialManager.storeAccessToken(testToken, expiresIn: expiresIn)

        let retrievedToken = credentialManager.getAccessToken()
        XCTAssertEqual(retrievedToken, testToken)
    }

    func testExpiredTokenRetrieval() throws {
        let testToken = "expired-token"
        let expiresIn: TimeInterval = -3600 // Already expired

        try credentialManager.storeAccessToken(testToken, expiresIn: expiresIn)

        let retrievedToken = credentialManager.getAccessToken()
        XCTAssertNil(retrievedToken, "Should not return expired token")
    }

    // MARK: - AuthManager Tests

    func testMSALInitializationWithoutConfiguration() async {
        // Clear any existing configuration
        try? await credentialManager.clearConfiguration()

        do {
            try await authManager.initializeMSAL()
            XCTFail("Should have thrown not configured error")
        } catch {
            // Expected error
            XCTAssertTrue(error.localizedDescription.contains("not configured"))
        }
    }

    func testMSALInitializationWithValidConfiguration() async throws {
        // Save valid configuration
        let config = AppConfiguration(
            clientId: "test-client-id",
            tenantId: "common",
            clientSecret: nil,
            redirectUri: "msauth.com.test://auth"
        )
        try await credentialManager.saveConfiguration(config)

        // Note: This will fail in tests without proper MSAL setup
        // but validates the configuration flow
        do {
            try await authManager.initializeMSAL()
        } catch {
            // MSAL initialization may fail in test environment
            // Check that we got past configuration validation
            XCTAssertFalse(error.localizedDescription.contains("not configured"))
        }
    }

    func testTokenValidationWithoutAuthentication() async {
        let isValid = await authManager.validateToken()
        XCTAssertFalse(isValid, "Should not be valid without authentication")
    }

    func testSignOutClearsState() async {
        await authManager.signOut()

        XCTAssertFalse(authManager.isAuthenticated)
        XCTAssertNil(authManager.currentUser)
        XCTAssertNil(authManager.tokenExpirationDate)
        XCTAssertNil(credentialManager.getAccessToken())
    }

    // MARK: - Configuration Update Tests

    func testUpdateConfiguration() async throws {
        // Save initial configuration
        let initialConfig = AppConfiguration(
            clientId: "initial-client-id",
            tenantId: "initial-tenant-id",
            clientSecret: nil,
            redirectUri: "msauth.com.test://auth"
        )
        try await credentialManager.saveConfiguration(initialConfig)

        // Update configuration
        let updates = ConfigurationUpdate(
            clientId: "updated-client-id",
            tenantId: "updated-tenant-id"
        )
        try await credentialManager.updateConfiguration(updates)

        XCTAssertEqual(credentialManager.configuration?.clientId, "updated-client-id")
        XCTAssertEqual(credentialManager.configuration?.tenantId, "updated-tenant-id")
    }

    func testUpdateConfigurationWithSecret() async throws {
        // Save initial configuration without secret
        let initialConfig = AppConfiguration(
            clientId: "test-client-id",
            tenantId: "test-tenant-id",
            clientSecret: nil,
            redirectUri: "msauth.com.test://auth"
        )
        try await credentialManager.saveConfiguration(initialConfig)

        // Update with secret
        let updates = ConfigurationUpdate(
            clientSecret: "new-secret",
            updateSecret: true
        )
        try await credentialManager.updateConfiguration(updates)

        XCTAssertEqual(credentialManager.configuration?.clientSecret, "new-secret")
        XCTAssertFalse(credentialManager.configuration?.isPublicClient ?? true)
    }

    // MARK: - Validation Tests

    func testValidateConfiguration() async {
        // Test with no configuration
        var isValid = await credentialManager.validateConfiguration()
        XCTAssertFalse(isValid)

        // Test with valid configuration
        let config = AppConfiguration(
            clientId: "test-client-id",
            tenantId: "test-tenant-id",
            clientSecret: nil,
            redirectUri: "msauth.com.test://auth"
        )
        try? await credentialManager.saveConfiguration(config)

        isValid = await credentialManager.validateConfiguration()
        XCTAssertTrue(isValid)
    }

    // MARK: - Error Handling Tests

    func testAuthErrorMessages() {
        let errors: [AuthError] = [
            .notConfigured,
            .msalNotInitialized,
            .invalidViewController,
            .notAuthenticated,
            .unknownError,
            .userCancelled,
            .insufficientPermissions,
            .networkError,
            .interactionRequired,
            .invalidConfiguration("Test details"),
            .msalInitializationFailed(NSError(domain: "Test", code: 1)),
            .signInFailed(NSError(domain: "Test", code: 2)),
            .tokenAcquisitionFailed(NSError(domain: "Test", code: 3))
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty, "Error should have description: \(error)")
        }
    }

    // MARK: - Performance Tests

    func testCredentialSavePerformance() {
        let config = AppConfiguration(
            clientId: "test-client-id",
            tenantId: "test-tenant-id",
            clientSecret: nil,
            redirectUri: "msauth.com.test://auth"
        )

        measure {
            Task {
                try? await credentialManager.saveConfiguration(config)
            }
        }
    }

    func testTokenRetrievalPerformance() {
        // Store a token first
        try? credentialManager.storeAccessToken("test-token", expiresIn: 3600)

        measure {
            _ = credentialManager.getAccessToken()
        }
    }
}

// MARK: - Mock Objects for Testing

class MockMSALPublicClientApplication {
    var accounts: [Any] = []
    var shouldFailSilentToken = false
    var shouldFailInteractiveToken = false

    func allAccounts() throws -> [Any] {
        return accounts
    }

    func acquireTokenSilent(with parameters: Any, completionBlock: @escaping (Any?, Error?) -> Void) {
        if shouldFailSilentToken {
            completionBlock(nil, NSError(domain: "MSAL", code: 1))
        } else {
            // Return mock token
            completionBlock("mock-token", nil)
        }
    }

    func acquireToken(with parameters: Any, completionBlock: @escaping (Any?, Error?) -> Void) {
        if shouldFailInteractiveToken {
            completionBlock(nil, NSError(domain: "MSAL", code: 2))
        } else {
            // Return mock token
            completionBlock("mock-token", nil)
        }
    }
}

// MARK: - Integration Test Helper

class AuthenticationIntegrationHelper {
    static func performFullAuthenticationFlow() async throws {
        let credentialManager = CredentialManager.shared
        let authManager = AuthManagerV2.shared

        // Step 1: Configure credentials
        let config = AppConfiguration(
            clientId: ProcessInfo.processInfo.environment["TEST_CLIENT_ID"] ?? "",
            tenantId: ProcessInfo.processInfo.environment["TEST_TENANT_ID"] ?? "common",
            clientSecret: ProcessInfo.processInfo.environment["TEST_CLIENT_SECRET"],
            redirectUri: "msauth.com.test.intunemanager://auth"
        )

        guard config.isValid else {
            throw NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid test configuration"])
        }

        try await credentialManager.saveConfiguration(config)

        // Step 2: Initialize MSAL
        try await authManager.initializeMSAL()

        // Step 3: Attempt silent authentication
        if await authManager.validateToken() {
            print("✅ Silent authentication successful")
        } else {
            print("ℹ️ Silent authentication failed, interactive sign-in required")
        }

        // Step 4: Get access token
        let token = try await authManager.getAccessToken()
        print("✅ Access token acquired: \(token.prefix(20))...")

        // Step 5: Sign out
        await authManager.signOut()
        print("✅ Sign out successful")
    }
}