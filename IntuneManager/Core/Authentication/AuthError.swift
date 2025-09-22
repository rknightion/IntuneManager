import Foundation

enum AuthError: LocalizedError, Equatable {
    case custom(String)
    case signInFailed(Error)
    case tokenAcquisitionFailed(Error)
    case msalInitializationFailed(Error)
    case invalidConfiguration(String)
    case notConfigured
    case msalNotInitialized
    case invalidViewController
    case notAuthenticated
    case unknownError
    case userCancelled
    case insufficientPermissions
    case networkError
    case interactionRequired

    var errorDescription: String? {
        switch self {
        case .custom(let message):
            return message
        case .signInFailed(let error):
            return "Sign in failed: \(error.localizedDescription)"
        case .tokenAcquisitionFailed(let error):
            return "Token acquisition failed: \(error.localizedDescription)"
        case .msalInitializationFailed(let error):
            return "MSAL initialization failed: \(error.localizedDescription)"
        case .invalidConfiguration(let details):
            return "Invalid configuration: \(details)"
        case .notConfigured:
            return "App is not configured. Please provide credentials."
        case .msalNotInitialized:
            return "Authentication system not initialized"
        case .invalidViewController:
            return "Invalid view controller for authentication"
        case .notAuthenticated:
            return "User is not authenticated"
        case .unknownError:
            return "An unknown error occurred"
        case .userCancelled:
            return "Authentication was cancelled"
        case .insufficientPermissions:
            return "Insufficient permissions granted"
        case .networkError:
            return "Network connection error"
        case .interactionRequired:
            return "User interaction required"
        }
    }

    static func == (lhs: AuthError, rhs: AuthError) -> Bool {
        switch (lhs, rhs) {
        case (.custom(let a), .custom(let b)):
            return a == b
        case (.signInFailed(let a), .signInFailed(let b)):
            return (a as NSError) == (b as NSError)
        case (.tokenAcquisitionFailed(let a), .tokenAcquisitionFailed(let b)):
            return (a as NSError) == (b as NSError)
        case (.msalInitializationFailed(let a), .msalInitializationFailed(let b)):
            return (a as NSError) == (b as NSError)
        case (.invalidConfiguration(let a), .invalidConfiguration(let b)):
            return a == b
        case (.notConfigured, .notConfigured),
             (.msalNotInitialized, .msalNotInitialized),
             (.invalidViewController, .invalidViewController),
             (.notAuthenticated, .notAuthenticated),
             (.unknownError, .unknownError),
             (.userCancelled, .userCancelled),
             (.insufficientPermissions, .insufficientPermissions),
             (.networkError, .networkError),
             (.interactionRequired, .interactionRequired):
            return true
        default:
            return false
        }
    }
}