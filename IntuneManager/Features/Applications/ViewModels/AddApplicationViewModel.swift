import Foundation
import SwiftUI
import Combine

@MainActor
final class AddApplicationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    @Published var createdApp: Application?

    private let applicationService = ApplicationService.shared

    // MARK: - Android Store App

    func createAndroidStoreApp(
        displayName: String,
        description: String?,
        publisher: String,
        packageId: String,
        appStoreUrl: String?,
        minimumOS: String?,
        isFeatured: Bool,
        informationUrl: String?,
        privacyInformationUrl: String?,
        developer: String?,
        owner: String?,
        notes: String?
    ) async throws -> Application {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Build minimum OS requirement if specified
        var minimumSupportedOS: AndroidMinimumOperatingSystem?
        if let minimumOS = minimumOS, !minimumOS.isEmpty {
            minimumSupportedOS = AndroidMinimumOperatingSystem.forVersion(minimumOS)
        }

        let request = AndroidStoreAppRequest(
            displayName: displayName,
            description: description?.isEmpty == false ? description : nil,
            publisher: publisher,
            packageId: packageId,
            appStoreUrl: appStoreUrl?.isEmpty == false ? appStoreUrl : nil,
            minimumSupportedOperatingSystem: minimumSupportedOS,
            isFeatured: isFeatured,
            informationUrl: informationUrl?.isEmpty == false ? informationUrl : nil,
            privacyInformationUrl: privacyInformationUrl?.isEmpty == false ? privacyInformationUrl : nil,
            developer: developer?.isEmpty == false ? developer : nil,
            owner: owner?.isEmpty == false ? owner : nil,
            notes: notes?.isEmpty == false ? notes : nil
        )

        do {
            let app = try await applicationService.createAndroidStoreApp(request)
            createdApp = app
            return app
        } catch {
            self.error = error
            throw error
        }
    }

    // MARK: - Android Enterprise System App

    func createAndroidEnterpriseSystemApp(
        displayName: String,
        publisher: String,
        packageId: String
    ) async throws -> Application {
        isLoading = true
        error = nil
        defer { isLoading = false }

        let request = AndroidManagedStoreAppRequest(
            displayName: displayName,
            publisher: publisher,
            packageId: packageId
        )

        do {
            let app = try await applicationService.createAndroidEnterpriseSystemApp(request)
            createdApp = app
            return app
        } catch {
            self.error = error
            throw error
        }
    }

    // MARK: - Validation Helpers

    /// Validates package ID format
    func validatePackageId(_ packageId: String) -> String? {
        do {
            try ValidationHelper.validatePackageId(packageId)
            return nil // No error
        } catch let error as AndroidAppValidationError {
            return error.errorDescription
        } catch {
            return error.localizedDescription
        }
    }

    /// Validates URL format
    func validateURL(_ url: String, fieldName: String) -> String? {
        guard !url.isEmpty else { return nil } // Empty is allowed for optional fields

        do {
            try ValidationHelper.validateURL(url, fieldName: fieldName)
            return nil // No error
        } catch let error as AndroidAppValidationError {
            return error.errorDescription
        } catch {
            return error.localizedDescription
        }
    }

    /// Extracts package ID from a Play Store URL
    func extractPackageIdFromURL(_ url: String) -> String? {
        // Play Store URLs: https://play.google.com/store/apps/details?id=com.example.app
        guard let urlComponents = URLComponents(string: url),
              let queryItems = urlComponents.queryItems,
              let idItem = queryItems.first(where: { $0.name == "id" }),
              let packageId = idItem.value else {
            return nil
        }
        return packageId
    }

    /// Gets user-friendly error message from an error
    func errorMessage(from error: Error) -> String {
        if let validationError = error as? AndroidAppValidationError {
            return validationError.errorDescription ?? error.localizedDescription
        }

        if let graphError = error as? GraphAPIError {
            switch graphError {
            case .httpError(let statusCode):
                switch statusCode {
                case 400:
                    return "Invalid request. Please check all fields and try again."
                case 403:
                    return "You don't have permission to create applications. Contact your administrator."
                case 409:
                    return "An app with this package ID may already exist."
                default:
                    return "Server error (\(statusCode)). Please try again."
                }
            case .unauthorized:
                return "Not authorized. Please sign in again."
            case .rateLimited:
                return "Too many requests. Please wait a moment and try again."
            default:
                return graphError.localizedDescription
            }
        }

        return error.localizedDescription
    }
}
