import Foundation
import Combine
import MSAL
import Security

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

            // Configure keychain for token storage
            #if os(macOS)
            // macOS uses default keychain configuration
            Logger.shared.info("Using default keychain configuration for macOS")
            #else
            // iOS can use keychain normally
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                if let teamID = resolveTeamIdentifierPrefix() {
                    let keychainGroup = "\(teamID).\(bundleIdentifier)"
                    msalConfig.cacheConfig.keychainSharingGroup = keychainGroup
                    Logger.shared.debug("MSAL Keychain Group: \(keychainGroup)")
                }
            }
            #endif

            // Configure MSAL logging to only show warnings and errors
            MSALGlobalConfig.loggerConfig.logLevel = .warning
            MSALGlobalConfig.loggerConfig.setLogCallback { (level, message, containsPII) in
                if !containsPII {
                    switch level {
                    case .error:
                        Logger.shared.error("MSAL: \(message ?? "")")
                    case .warning:
                        Logger.shared.warning("MSAL: \(message ?? "")")
                    default:
                        // Ignore info, verbose, and other levels
                        break
                    }
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

        // Create interactive parameters with webview
        #if os(iOS)
        guard let presentingViewController = viewController as? UIViewController else {
            throw AuthError.invalidViewController
        }
        let webviewParameters = MSALWebviewParameters(authPresentationViewController: presentingViewController)
        #elseif os(macOS)
        // For macOS, get the main window's content view controller
        // If none exists, we'll pass nil and MSAL will use the default browser
        let contentViewController = NSApplication.shared.mainWindow?.contentViewController ?? NSApplication.shared.keyWindow?.contentViewController
        let webviewParameters: MSALWebviewParameters

        if let vc = contentViewController {
            webviewParameters = MSALWebviewParameters(authPresentationViewController: vc)
        } else {
            // Create a minimal view controller to satisfy the requirement
            let vc = NSViewController()
            webviewParameters = MSALWebviewParameters(authPresentationViewController: vc)
        }

        // Use authentication session which opens system browser
        webviewParameters.webviewType = .authenticationSession
        #endif

        let interactiveParameters = MSALInteractiveTokenParameters(
            scopes: scopes,
            webviewParameters: webviewParameters
        )

        // Configure prompt type for account selection
        interactiveParameters.promptType = MSALPromptType.selectAccount

        // Set extra query parameters if needed
        // Only add domain_hint if not using "common" tenant
        if config.tenantId != "common" {
            interactiveParameters.extraQueryParameters = ["domain_hint": config.tenantId]
        }

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
            // Log more details about the MSAL error
            Logger.shared.error("MSAL Sign In Failed - Code: \(error.code), Domain: \(error.domain)")
            Logger.shared.error("Error Details: \(error.localizedDescription)")
            if let msalError = error.userInfo[MSALErrorDescriptionKey] as? String {
                Logger.shared.error("MSAL Error Description: \(msalError)")
            }
            if let msalOAuthError = error.userInfo[MSALOAuthErrorKey] as? String {
                Logger.shared.error("MSAL OAuth Error: \(msalOAuthError)")
            }
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

        // Token is now automatically stored in our custom in-memory cache
        // No need for additional storage as the custom cache handles it

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

    private func resolveTeamIdentifierPrefix() -> String? {
        if let prefixes = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? [String],
           let prefix = prefixes.first {
            return sanitizeTeamIdentifier(prefix)
        }

        if let prefix = Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String {
            return sanitizeTeamIdentifier(prefix)
        }

        #if os(macOS)
        if let prefix = fetchTeamIdentifierFromCodeSigning() {
            return sanitizeTeamIdentifier(prefix)
        }
        #endif

        return nil
    }

    private func sanitizeTeamIdentifier(_ identifier: String) -> String {
        identifier.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    }

    #if os(macOS)
    private func fetchTeamIdentifierFromCodeSigning() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else {
            return nil
        }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else {
            return nil
        }

        var signingInfo: CFDictionary?
        guard SecCodeCopySigningInformation(staticCode, SecCSFlags(), &signingInfo) == errSecSuccess,
              let info = signingInfo as? [String: Any],
              let entitlements = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any],
              let applicationIdentifier = entitlements["application-identifier"] as? String,
              let prefix = applicationIdentifier.split(separator: ".").first else {
            return nil
        }

        return String(prefix)
    }
    #endif
}
