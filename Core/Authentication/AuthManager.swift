import Foundation
import MSAL
import KeychainAccess

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false

    private var applicationContext: MSALPublicClientApplication?
    private let keychain = Keychain(service: "com.intunemanager.auth")
    private var account: MSALAccount?

    struct User {
        let id: String
        let displayName: String
        let email: String
    }

    private init() {
        Task {
            await initializeMSAL()
        }
    }

    private func initializeMSAL() async {
        do {
            let config = MSALConfiguration.current
            let msalConfig = MSALPublicClientApplicationConfig(clientId: config.clientId,
                                                                 redirectUri: config.redirectUri,
                                                                 authority: config.authority)

            msalConfig.knownAuthorities = [config.authority]

            #if os(macOS)
            // macOS specific configuration
            msalConfig.redirectUri = "msauth.\(config.bundleId)://auth"
            #endif

            applicationContext = try await withCheckedThrowingContinuation { continuation in
                do {
                    let context = try MSALPublicClientApplication(configuration: msalConfig)
                    continuation.resume(returning: context)
                } catch {
                    continuation.resume(throwing: error)
                }
            }

            Logger.shared.info("MSAL initialized successfully")
        } catch {
            Logger.shared.error("Failed to initialize MSAL: \(error)")
        }
    }

    func checkAuthenticationState() async {
        guard let application = applicationContext else {
            Logger.shared.warning("MSAL not initialized")
            return
        }

        do {
            // Check for cached account
            let accounts = try application.allAccounts()
            if let firstAccount = accounts.first {
                self.account = firstAccount

                // Try to acquire token silently
                let parameters = MSALSilentTokenParameters(scopes: MSALConfiguration.current.scopes,
                                                           account: firstAccount)

                let result = try await withCheckedThrowingContinuation { continuation in
                    application.acquireTokenSilent(with: parameters) { (result, error) in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let result = result {
                            continuation.resume(returning: result)
                        }
                    }
                }

                await handleAuthenticationResult(result)
            }
        } catch {
            Logger.shared.info("Silent authentication failed, user needs to sign in: \(error)")
            isAuthenticated = false
        }
    }

    func signIn() async throws {
        guard let application = applicationContext else {
            throw AuthError.msalNotInitialized
        }

        isLoading = true
        defer { isLoading = false }

        let parameters = MSALInteractiveTokenParameters(scopes: MSALConfiguration.current.scopes)

        #if os(iOS)
        // iOS specific - need to provide presenting view controller
        if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = await windowScene.windows.first?.rootViewController {
            parameters.presentationViewController = rootViewController
        }
        #elseif os(macOS)
        // macOS will handle the web authentication session automatically
        parameters.promptType = .selectAccount
        #endif

        parameters.completionBlockQueue = DispatchQueue.main

        let result = try await withCheckedThrowingContinuation { continuation in
            application.acquireToken(with: parameters) { (result, error) in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let result = result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: AuthError.unknownError)
                }
            }
        }

        await handleAuthenticationResult(result)
    }

    func signOut() async {
        guard let application = applicationContext else { return }

        if let account = account {
            do {
                #if os(iOS)
                // iOS specific signout
                let parameters = MSALSignoutParameters()
                if let windowScene = await UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let rootViewController = await windowScene.windows.first?.rootViewController {
                    parameters.presentationViewController = rootViewController
                }

                try await withCheckedThrowingContinuation { continuation in
                    application.signout(with: account, signoutParameters: parameters) { (success, error) in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }
                #elseif os(macOS)
                // macOS signout
                let removeAccountResult = try application.remove(account)
                Logger.shared.info("Account removed: \(removeAccountResult)")
                #endif

                // Clear stored tokens
                try? keychain.removeAll()

                // Reset state
                self.account = nil
                self.currentUser = nil
                self.isAuthenticated = false

                Logger.shared.info("User signed out successfully")
            } catch {
                Logger.shared.error("Sign out error: \(error)")
            }
        }
    }

    func acquireToken() async throws -> String {
        guard let application = applicationContext,
              let account = account else {
            throw AuthError.notAuthenticated
        }

        // First try silent acquisition
        let silentParameters = MSALSilentTokenParameters(scopes: MSALConfiguration.current.scopes,
                                                          account: account)

        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                application.acquireTokenSilent(with: silentParameters) { (result, error) in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let result = result {
                        continuation.resume(returning: result)
                    }
                }
            }
            return result.accessToken
        } catch {
            // If silent fails, try interactive
            Logger.shared.warning("Silent token acquisition failed, trying interactive: \(error)")
            try await signIn()

            // After successful sign in, we should have a token
            guard let token = try? keychain.getString("accessToken") else {
                throw AuthError.tokenAcquisitionFailed
            }
            return token
        }
    }

    private func handleAuthenticationResult(_ result: MSALResult) async {
        // Store tokens securely
        do {
            try keychain.set(result.accessToken, key: "accessToken")
            if let refreshToken = result.account.identifier {
                try keychain.set(refreshToken, key: "refreshToken")
            }
        } catch {
            Logger.shared.error("Failed to store tokens: \(error)")
        }

        // Update account and user info
        self.account = result.account
        self.currentUser = User(
            id: result.account.identifier ?? "",
            displayName: result.account.username ?? "Unknown User",
            email: result.account.username ?? ""
        )
        self.isAuthenticated = true

        Logger.shared.info("User authenticated: \(result.account.username ?? "Unknown")")
    }
}

enum AuthError: LocalizedError {
    case msalNotInitialized
    case notAuthenticated
    case tokenAcquisitionFailed
    case unknownError

    var errorDescription: String? {
        switch self {
        case .msalNotInitialized:
            return "Authentication system not initialized"
        case .notAuthenticated:
            return "User is not authenticated"
        case .tokenAcquisitionFailed:
            return "Failed to acquire access token"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}