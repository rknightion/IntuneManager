import Foundation
import Combine
import MSAL

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

/// Updated Authentication Manager using MSAL v2 with improved error handling and session management
@MainActor
class AuthManagerV2: ObservableObject {
    static let shared = AuthManagerV2()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var authenticationError: AuthError?
    @Published var tokenExpirationDate: Date?

    private var applicationContext: MSALPublicClientApplication?
    private let credentialManager = CredentialManager.shared
    private var currentAccount: MSALAccount?
    private var tokenRefreshTimer: Timer?

    struct User {
        let id: String
        let displayName: String
        let email: String
        let tenantId: String?
    }

    private init() {
        // Setup notification observers for app lifecycle
        setupLifecycleObservers()
    }

    // MARK: - MSAL Initialization

    /// Initializes MSAL with stored or provided configuration
    func initializeMSAL() async throws {
        guard let config = credentialManager.configuration else {
            throw AuthError.notConfigured
        }

        do {
            // Create MSAL configuration
            guard let authorityURL = URL(string: config.authority) else {
                throw AuthError.invalidConfiguration("Invalid authority URL")
            }

            let authority = try MSALAADAuthority(url: authorityURL)

            let msalConfig = MSALPublicClientApplicationConfig(
                clientId: config.clientId,
                redirectUri: config.redirectUri,
                authority: authority
            )

            // Configure for public client (no secret)
            msalConfig.clientApplicationCapabilities = ["CP1"] // Claims challenge capability

            // Enable logging for debugging
            MSALGlobalConfig.loggerConfig.logLevel = .verbose
            MSALGlobalConfig.loggerConfig.setLogCallback { (level, message, containsPII) in
                if !containsPII {
                    Logger.shared.debug("MSAL: \(message ?? "")")
                }
            }

            // Initialize MSAL application
            applicationContext = try MSALPublicClientApplication(configuration: msalConfig)

            Logger.shared.info("MSAL v2 initialized successfully with tenant: \(config.tenantId)")

            // Check for cached account
            await checkCachedAccount()

        } catch let error as NSError {
            Logger.shared.error("MSAL initialization failed: \(error.localizedDescription)")
            throw AuthError.msalInitializationFailed(error)
        }
    }

    // MARK: - Authentication Methods

    /// Checks for cached account and attempts silent token acquisition
    private func checkCachedAccount() async {
        guard let application = applicationContext else { return }

        do {
            // Get all accounts from cache
            let parameters = MSALAccountEnumerationParameters()
            let accounts = try application.accounts(for: parameters)

            if let account = accounts.first {
                currentAccount = account
                // Attempt silent token acquisition
                _ = try? await acquireTokenSilently()
            }
        } catch {
            Logger.shared.info("No cached accounts found: \(error)")
        }
    }

    /// Interactive sign-in flow
    func signIn(from viewController: Any? = nil) async throws {
        guard let application = applicationContext else {
            throw AuthError.msalNotInitialized
        }

        guard let config = credentialManager.configuration else {
            throw AuthError.notConfigured
        }

        isLoading = true
        authenticationError = nil
        defer { isLoading = false }

        // Define required scopes
        let scopes = [
            "https://graph.microsoft.com/User.Read",
            "https://graph.microsoft.com/DeviceManagementManagedDevices.Read.All",
            "https://graph.microsoft.com/DeviceManagementApps.Read.All",
            "https://graph.microsoft.com/Group.Read.All"
        ]

        // Setup webview parameters based on platform
        #if os(iOS)
        guard let presentingViewController = viewController as? UIViewController else {
            throw AuthError.invalidViewController
        }
        let webviewParameters = MSALWebviewParameters(authPresentationViewController: presentingViewController)
        #elseif os(macOS)
        // For macOS, we need a view controller or we can't proceed
        guard let presentingViewController = viewController as? NSViewController else {
            // On macOS, if no view controller is provided, we cannot show the auth UI
            throw AuthError.invalidViewController
        }
        let webviewParameters = MSALWebviewParameters(authPresentationViewController: presentingViewController)
        #endif

        // Create interactive parameters with webview
        let interactiveParameters = MSALInteractiveTokenParameters(
            scopes: scopes,
            webviewParameters: webviewParameters
        )

        // Configure prompt type for account selection
        interactiveParameters.promptType = MSALPromptType.selectAccount

        // Set extra query parameters if needed
        interactiveParameters.extraQueryParameters = ["domain_hint": config.tenantId]

        do {
            let result: MSALResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, any Error>) in
                application.acquireToken(with: interactiveParameters) { (result, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: AuthError.unknownError)
                    }
                }
            }

            handleAuthenticationSuccess(result)

        } catch let error as NSError {
            handleAuthenticationError(error)
            throw AuthError.signInFailed(error)
        }
    }

    /// Silent token acquisition
    func acquireTokenSilently() async throws -> String {
        guard let application = applicationContext,
              let account = currentAccount else {
            throw AuthError.notAuthenticated
        }

        guard credentialManager.configuration != nil else {
            throw AuthError.notConfigured
        }

        let scopes = [
            "https://graph.microsoft.com/User.Read",
            "https://graph.microsoft.com/DeviceManagementManagedDevices.Read.All",
            "https://graph.microsoft.com/DeviceManagementApps.Read.All",
            "https://graph.microsoft.com/Group.Read.All"
        ]

        let silentParameters = MSALSilentTokenParameters(scopes: scopes, account: account)

        // Force refresh if token is about to expire
        if let expirationDate = tokenExpirationDate,
           expirationDate.timeIntervalSinceNow < 300 { // Less than 5 minutes
            silentParameters.forceRefresh = true
        }

        do {
            let result: MSALResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<MSALResult, any Error>) in
                application.acquireTokenSilent(with: silentParameters) { (result, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(throwing: AuthError.unknownError)
                    }
                }
            }

            handleAuthenticationSuccess(result)
            return result.accessToken

        } catch let error as NSError {
            // Check if interaction is required
            if error.domain == MSALErrorDomain,
               let errorCode = MSALError(rawValue: error.code),
               errorCode == .interactionRequired {
                Logger.shared.info("User interaction required for token refresh")
                throw AuthError.interactionRequired
            }

            Logger.shared.error("Silent token acquisition failed: \(error)")
            throw AuthError.tokenAcquisitionFailed(error)
        }
    }

    /// Sign out current user
    func signOut() async {
        guard let application = applicationContext else { return }

        isLoading = true
        defer { isLoading = false }

        if let account = currentAccount {
            do {
                // Remove account from cache
                let signoutParameters: MSALSignoutParameters

                #if os(iOS)
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootVC = (windowScene.windows.first { $0.isKeyWindow } ?? windowScene.windows.first)?.rootViewController {
                    let webviewParameters = MSALWebviewParameters(authPresentationViewController: rootVC)
                    signoutParameters = MSALSignoutParameters(webviewParameters: webviewParameters)
                } else {
                    signoutParameters = MSALSignoutParameters()
                }
                #else
                signoutParameters = MSALSignoutParameters()
                #endif

                signoutParameters.signoutFromBrowser = true

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    application.signout(with: account, signoutParameters: signoutParameters) { success, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }

                // Clear local state
                clearAuthenticationState()

                Logger.shared.info("User signed out successfully")

            } catch {
                Logger.shared.error("Sign out failed: \(error)")
                // Force clear state even if signout fails
                clearAuthenticationState()
            }
        } else {
            clearAuthenticationState()
        }
    }

    // MARK: - Token Management

    /// Gets current access token, refreshing if necessary
    func getAccessToken() async throws -> String {
        if isAuthenticated, let _ = currentAccount {
            return try await acquireTokenSilently()
        } else {
            throw AuthError.notAuthenticated
        }
    }

    /// Validates current token
    func validateToken() async -> Bool {
        guard let _ = currentAccount else { return false }

        do {
            _ = try await acquireTokenSilently()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Private Helpers

    private func handleAuthenticationSuccess(_ result: MSALResult) {
        // Update account
        currentAccount = result.account

        // Extract user information
        let claims = result.account.accountClaims
        let displayName = claims?["name"] as? String ?? result.account.username ?? "Unknown User"
        let email = result.account.username ?? ""
        let tenantId = result.tenantProfile.tenantId

        currentUser = User(
            id: result.account.identifier ?? "",
            displayName: displayName,
            email: email,
            tenantId: tenantId
        )

        // Store token information
        tokenExpirationDate = result.expiresOn

        // Update authentication state
        isAuthenticated = true
        authenticationError = nil

        // MSAL handles token storage automatically in the keychain
        // No need to manually store tokens

        // Setup token refresh timer
        setupTokenRefreshTimer()

        Logger.shared.info("Authentication successful for user: \(displayName)")
    }

    private func handleAuthenticationError(_ error: NSError) {
        clearAuthenticationState()

        // Parse MSAL error
        if error.domain == MSALErrorDomain {
            if let errorCode = MSALError(rawValue: error.code) {
                switch errorCode {
                case .userCanceled:
                    authenticationError = .userCancelled
                case .serverDeclinedScopes:
                    authenticationError = .insufficientPermissions
                case .interactionRequired:
                    authenticationError = .interactionRequired
                default:
                    authenticationError = .signInFailed(error)
                }
            } else {
                authenticationError = .signInFailed(error)
            }
        } else {
            authenticationError = .signInFailed(error)
        }

        Logger.shared.error("Authentication error: \(error.localizedDescription)")
    }

    private func clearAuthenticationState() {
        currentAccount = nil
        currentUser = nil
        isAuthenticated = false
        tokenExpirationDate = nil
        authenticationError = nil

        // MSAL handles clearing tokens from its cache
        // No manual token clearing needed

        // Cancel token refresh timer
        tokenRefreshTimer?.invalidate()
        tokenRefreshTimer = nil
    }

    // MARK: - Token Refresh Management

    private func setupTokenRefreshTimer() {
        tokenRefreshTimer?.invalidate()

        guard let expirationDate = tokenExpirationDate else { return }

        // Refresh 5 minutes before expiration
        let refreshDate = expirationDate.addingTimeInterval(-300)
        let timeInterval = refreshDate.timeIntervalSinceNow

        if timeInterval > 0 {
            tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
                Task {
                    do {
                        _ = try await self.acquireTokenSilently()
                        await Logger.shared.info("Token refreshed automatically")
                    } catch {
                        await Logger.shared.error("Automatic token refresh failed: \(error)")
                    }
                }
            }
        }
    }

    // MARK: - Lifecycle Management

    private func setupLifecycleObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        #elseif os(macOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        #endif
    }

    @objc private func handleAppDidBecomeActive() {
        // Validate token when app becomes active
        Task { [weak self] in
            guard let self = self else { return }
            if self.isAuthenticated {
                do {
                    _ = try await self.acquireTokenSilently()
                } catch {
                    // Ignore here; validation failures are non-fatal on activation
                }
            }
        }
    }

    @objc private func handleAppWillResignActive() {
        // Pause token refresh timer when app goes to background
        tokenRefreshTimer?.invalidate()
    }
}

