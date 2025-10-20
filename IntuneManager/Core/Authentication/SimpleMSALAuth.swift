import Foundation
import Combine
import MSAL
import AppKit

/// Simplified MSAL authentication manager following Microsoft's official documentation
/// This implementation goes back to basics to avoid keychain issues
@MainActor
class SimpleMSALAuth: ObservableObject {

    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var accessToken: String?
    @Published var userDisplayName: String?
    @Published var errorMessage: String?

    // MARK: - Configuration
    private let kClientID = "your-client-id" // Will be replaced from config
    private let kAuthority = "https://login.microsoftonline.com/common"
    private let kGraphEndpoint = "https://graph.microsoft.com/"
    private let kScopes: [String] = ["user.read"]

    // MARK: - MSAL Properties
    private var applicationContext: MSALPublicClientApplication?
    private var webViewParameters: MSALWebviewParameters?
    private var currentAccount: MSALAccount?

    // MARK: - Initialization
    init() {
        do {
            try initMSAL()
        } catch {
            self.errorMessage = "Failed to initialize MSAL: \(error.localizedDescription)"
            print("MSAL initialization error: \(error)")
        }
    }

    /// Initialize MSAL following the official documentation exactly
    private func initMSAL() throws {
        guard let authorityURL = URL(string: kAuthority) else {
            throw NSError(domain: "SimpleMSAL", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create authority URL"])
        }

        let authority = try MSALAADAuthority(url: authorityURL)

        // Create configuration exactly as shown in documentation
        let msalConfiguration = MSALPublicClientApplicationConfig(
            clientId: kClientID,
            redirectUri: nil, // Let MSAL use default
            authority: authority
        )

        // Initialize application context
        self.applicationContext = try MSALPublicClientApplication(configuration: msalConfiguration)

        // Initialize web view parameters
        self.initWebViewParams()

        print("MSAL initialized successfully")
    }

    /// Initialize web view parameters for authentication
    private func initWebViewParams() {
        if let contentViewController = NSApplication.shared.mainWindow?.contentViewController ??
            NSApplication.shared.keyWindow?.contentViewController {
            self.webViewParameters = MSALWebviewParameters(authPresentationViewController: contentViewController)
        } else {
            // Create a minimal view controller if none exists
            let vc = NSViewController()
            self.webViewParameters = MSALWebviewParameters(authPresentationViewController: vc)
        }
        // Use authentication session (system browser) to avoid in-app browser issues
        self.webViewParameters?.webviewType = .authenticationSession
    }

    // MARK: - Sign In

    /// Sign in interactively - following documentation pattern exactly
    func signIn() {
        guard let applicationContext = self.applicationContext else {
            self.errorMessage = "MSAL not initialized"
            return
        }

        // Ensure web view parameters reflect the current window state
        if webViewParameters == nil {
            initWebViewParams()
        }

        guard let webViewParameters = self.webViewParameters else {
            self.errorMessage = "Web view parameters not configured"
            return
        }

        // Create interactive parameters exactly as shown in documentation
        let parameters = MSALInteractiveTokenParameters(scopes: kScopes, webviewParameters: webViewParameters)
        parameters.promptType = .selectAccount

        // Clear any previous error
        self.errorMessage = nil

        // Acquire token interactively
        applicationContext.acquireToken(with: parameters) { [weak self] (result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    self?.handleError(error)
                    return
                }

                guard let result = result else {
                    self?.errorMessage = "No result returned from sign-in"
                    return
                }

                // Success! Store the results
                self?.accessToken = result.accessToken
                self?.currentAccount = result.account
                self?.userDisplayName = result.account.username ?? "Unknown User"
                self?.isAuthenticated = true

                print("Sign-in successful for user: \(result.account.username ?? "unknown")")
                print("Access token acquired (first 20 chars): \(String(result.accessToken.prefix(20)))...")
            }
        }
    }

    // MARK: - Sign Out

    /// Sign out the current user
    func signOut() {
        guard let applicationContext = self.applicationContext else { return }

        guard let account = self.currentAccount else {
            self.errorMessage = "No account to sign out"
            return
        }

        // Remove account from cache
        do {
            try applicationContext.remove(account)

            // Clear local state
            self.currentAccount = nil
            self.accessToken = nil
            self.userDisplayName = nil
            self.isAuthenticated = false
            self.errorMessage = nil

            print("Sign-out successful")
        } catch {
            self.errorMessage = "Sign-out failed: \(error.localizedDescription)"
            print("Sign-out error: \(error)")
        }
    }

    // MARK: - Token Acquisition

    /// Acquire token silently (for subsequent API calls after initial sign-in)
    func acquireTokenSilently() {
        guard let applicationContext = self.applicationContext else {
            self.errorMessage = "MSAL not initialized"
            return
        }

        guard let account = self.currentAccount else {
            self.errorMessage = "No account available - please sign in"
            return
        }

        let parameters = MSALSilentTokenParameters(scopes: kScopes, account: account)

        applicationContext.acquireTokenSilent(with: parameters) { [weak self] (result, error) in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError

                    // Check if interaction is required
                    if nsError.domain == MSALErrorDomain &&
                       nsError.code == MSALError.interactionRequired.rawValue {
                        print("User interaction required - need to sign in again")
                        self?.errorMessage = "Please sign in again"
                        self?.isAuthenticated = false
                    } else {
                        self?.handleError(error)
                    }
                    return
                }

                guard let result = result else {
                    self?.errorMessage = "No result returned from silent token acquisition"
                    return
                }

                // Update access token
                self?.accessToken = result.accessToken
                print("Token refreshed silently")
            }
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        let nsError = error as NSError

        print("MSAL Error - Domain: \(nsError.domain), Code: \(nsError.code)")
        print("Error Details: \(nsError.localizedDescription)")

        // Check for specific error codes
        if nsError.code == -34018 {
            // Keychain access error
            self.errorMessage = """
            ⚠️ Keychain Access Error (-34018)

            The app cannot access the keychain in sandbox mode.
            MSAL requires keychain access to store tokens.

            Solution: Either disable app sandbox or add proper keychain entitlements.
            """
        } else if let msalError = nsError.userInfo[MSALErrorDescriptionKey] as? String {
            self.errorMessage = msalError
        } else {
            self.errorMessage = nsError.localizedDescription
        }

        // Log additional MSAL error info if available
        if let msalOAuthError = nsError.userInfo[MSALOAuthErrorKey] as? String {
            print("OAuth Error: \(msalOAuthError)")
        }

        if let msalSubError = nsError.userInfo[MSALOAuthSubErrorKey] as? String {
            print("OAuth Sub Error: \(msalSubError)")
        }
    }

    // MARK: - Configuration Update

    /// Update configuration with actual values
    func updateConfiguration(clientId: String, tenantId: String) {
        // Since kClientID is a let constant, we need to reinitialize
        // In a real app, you'd want to make these properties that can be updated
        do {
            // Create new authority URL with tenant
            let authorityString = tenantId == "common" ?
                "https://login.microsoftonline.com/common" :
                "https://login.microsoftonline.com/\(tenantId)"

            guard let authorityURL = URL(string: authorityString) else {
                throw NSError(domain: "SimpleMSAL", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid authority URL"])
            }

            let authority = try MSALAADAuthority(url: authorityURL)

            // Create new configuration with actual client ID
            let msalConfiguration = MSALPublicClientApplicationConfig(
                clientId: clientId,
                redirectUri: nil,
                authority: authority
            )

            // Reinitialize application context
            self.applicationContext = try MSALPublicClientApplication(configuration: msalConfiguration)

            print("Configuration updated - Client ID: \(clientId), Tenant: \(tenantId)")
        } catch {
            self.errorMessage = "Failed to update configuration: \(error.localizedDescription)"
            print("Configuration update error: \(error)")
        }
    }
}
