import Foundation
import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - Request/Response Models (must be outside @MainActor for Sendable conformance)

struct MacOSCustomConfigurationRequest: Codable, Sendable {
    let odataType: String = "#microsoft.graph.macOSCustomConfiguration"
    let displayName: String
    let description: String
    let payloadFileName: String
    let payload: String
    let deploymentChannel: String = "deviceChannel"
    let priority: Int = 0

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case displayName
        case description
        case payloadFileName
        case payload
        case deploymentChannel
        case priority
    }
}

struct IOSCustomConfigurationRequest: Codable, Sendable {
    let odataType: String = "#microsoft.graph.iosCustomConfiguration"
    let displayName: String
    let description: String
    let payloadFileName: String
    let payload: String
    let deploymentChannel: String = "deviceChannel"
    let priority: Int = 0

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case displayName
        case description
        case payloadFileName
        case payload
        case deploymentChannel
        case priority
    }
}

struct DeviceConfigurationAssignmentRequest: Codable, Sendable {
    let odataType: String = "#microsoft.graph.deviceConfigurationAssignment"
    let target: AssignmentTargetRequest

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case target
    }
}

struct DeviceConfigurationAssignmentResponse: Codable, Sendable {
    let id: String
}

struct AssignmentTargetRequest: Codable, Sendable {
    let odataType: String
    let groupId: String?

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case groupId
    }
}

struct ConfigurationProfileResponse: Codable, Sendable {
    let id: String
    let displayName: String
    let description: String?
    let createdDateTime: Date?
    let lastModifiedDateTime: Date?
    let version: Int?
}

@MainActor
final class MobileConfigService: ObservableObject {
    static let shared = MobileConfigService()

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0.0
    @Published var lastError: Error?

    private let graphClient = GraphAPIClient.shared
    private let configurationService = ConfigurationService.shared

    private init() {}

    // MARK: - MobileConfig Upload

    /// Parse and validate a .mobileconfig file
    func validateMobileConfig(data: Data) throws -> MobileConfigInfo {
        // Parse the plist data
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw MobileConfigError.invalidFormat("Unable to parse .mobileconfig file")
        }

        // Extract metadata
        let payloadIdentifier = plist["PayloadIdentifier"] as? String ?? ""
        let payloadDisplayName = plist["PayloadDisplayName"] as? String ?? "Untitled Profile"
        let payloadDescription = plist["PayloadDescription"] as? String ?? ""
        let payloadOrganization = plist["PayloadOrganization"] as? String ?? ""
        let payloadType = plist["PayloadType"] as? String ?? "Configuration"
        let payloadUUID = plist["PayloadUUID"] as? String ?? UUID().uuidString
        let payloadVersion = plist["PayloadVersion"] as? Int ?? 1

        // Validate required fields
        guard !payloadIdentifier.isEmpty else {
            throw MobileConfigError.missingRequiredField("PayloadIdentifier")
        }

        // Extract payload content
        let payloadContent = plist["PayloadContent"] as? [[String: Any]] ?? []

        return MobileConfigInfo(
            identifier: payloadIdentifier,
            displayName: payloadDisplayName,
            description: payloadDescription,
            organization: payloadOrganization,
            type: payloadType,
            uuid: payloadUUID,
            version: payloadVersion,
            payloadCount: payloadContent.count,
            rawData: data
        )
    }

    /// Deploy a .mobileconfig as a custom configuration profile
    func deployMobileConfig(
        configInfo: MobileConfigInfo,
        platform: ConfigurationProfile.PlatformType,
        assignments: [ConfigurationAssignment]? = nil
    ) async throws -> ConfigurationProfile {
        return try await createCustomProfile(
            from: configInfo,
            platform: platform,
            assignments: assignments
        )
    }

    /// Create a custom configuration profile from .mobileconfig
    func createCustomProfile(
        from mobileConfig: MobileConfigInfo,
        platform: ConfigurationProfile.PlatformType,
        assignments: [ConfigurationAssignment]? = nil
    ) async throws -> ConfigurationProfile {
        isUploading = true
        defer { isUploading = false }

        let base64Payload = mobileConfig.rawData.base64EncodedString()

        // Create the appropriate request struct based on platform
        switch platform {
        case .macOS:
            let requestBody = MacOSCustomConfigurationRequest(
                displayName: mobileConfig.displayName,
                description: mobileConfig.description,
                payloadFileName: "\(mobileConfig.identifier).mobileconfig",
                payload: base64Payload
            )

            let response: ConfigurationProfileResponse = try await graphClient.postModel(
                "/deviceManagement/deviceConfigurations",
                body: requestBody
            )

            uploadProgress = 0.5

            // Apply assignments if provided
            if let assignments = assignments {
                try await assignToGroups(profileId: response.id, assignments: assignments)
            }

            uploadProgress = 1.0

            // Refresh profiles
            _ = try? await configurationService.fetchConfigurationProfiles(forceRefresh: true)

            // Convert response to ConfigurationProfile
            let profile = ConfigurationProfile(
                id: response.id,
                displayName: response.displayName,
                profileDescription: response.description,
                platformType: .macOS,
                profileType: .custom
            )
            if let created = response.createdDateTime {
                profile.createdDateTime = created
            }
            if let modified = response.lastModifiedDateTime {
                profile.lastModifiedDateTime = modified
            }
            if let ver = response.version {
                profile.version = ver
            }
            return profile

        case .iOS:
            let requestBody = IOSCustomConfigurationRequest(
                displayName: mobileConfig.displayName,
                description: mobileConfig.description,
                payloadFileName: "\(mobileConfig.identifier).mobileconfig",
                payload: base64Payload
            )

            let response: ConfigurationProfileResponse = try await graphClient.postModel(
                "/deviceManagement/deviceConfigurations",
                body: requestBody
            )

            uploadProgress = 0.5

            // Apply assignments if provided
            if let assignments = assignments {
                try await assignToGroups(profileId: response.id, assignments: assignments)
            }

            uploadProgress = 1.0

            // Refresh profiles
            _ = try? await configurationService.fetchConfigurationProfiles(forceRefresh: true)

            // Convert response to ConfigurationProfile
            let profile = ConfigurationProfile(
                id: response.id,
                displayName: response.displayName,
                profileDescription: response.description,
                platformType: .iOS,
                profileType: .custom
            )
            if let created = response.createdDateTime {
                profile.createdDateTime = created
            }
            if let modified = response.lastModifiedDateTime {
                profile.lastModifiedDateTime = modified
            }
            if let ver = response.version {
                profile.version = ver
            }
            return profile

        case .android, .androidEnterprise, .androidWorkProfile:
            throw MobileConfigError.unsupportedPlatform("Android - use App Configuration instead")

        case .windows10:
            throw MobileConfigError.unsupportedPlatform("Windows - use PowerShell scripts or Win32 apps instead")
        }
    }

    // MARK: - Assignment Management

    private func assignToGroups(
        profileId: String,
        assignments: [ConfigurationAssignment]
    ) async throws {
        for assignment in assignments {
            let assignmentRequest = DeviceConfigurationAssignmentRequest(
                target: buildAssignmentTarget(assignment.target)
            )

            let _: DeviceConfigurationAssignmentResponse = try await graphClient.postModel(
                "/deviceManagement/deviceConfigurations/\(profileId)/assignments",
                body: assignmentRequest
            )
        }
    }

    private func buildAssignmentTarget(_ target: ConfigurationAssignment.AssignmentTarget) -> AssignmentTargetRequest {
        switch target.type {
        case .allUsers:
            return AssignmentTargetRequest(
                odataType: "#microsoft.graph.allLicensedUsersAssignmentTarget",
                groupId: nil
            )

        case .allDevices:
            return AssignmentTargetRequest(
                odataType: "#microsoft.graph.allDevicesAssignmentTarget",
                groupId: nil
            )

        case .group:
            return AssignmentTargetRequest(
                odataType: "#microsoft.graph.groupAssignmentTarget",
                groupId: target.groupId
            )

        case .exclusionGroup:
            return AssignmentTargetRequest(
                odataType: "#microsoft.graph.exclusionGroupAssignmentTarget",
                groupId: target.groupId
            )

        case .allLicensedUsers:
            return AssignmentTargetRequest(
                odataType: "#microsoft.graph.allLicensedUsersAssignmentTarget",
                groupId: nil
            )
        }
    }

    // MARK: - Utility

    /// Extract profile name from .mobileconfig data
    func extractProfileName(from data: Data) -> String? {
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            return nil
        }

        return plist["PayloadDisplayName"] as? String
    }
}

// MARK: - Data Models

struct MobileConfigInfo {
    let identifier: String
    let displayName: String
    let description: String
    let organization: String
    let type: String
    let uuid: String
    let version: Int
    let payloadCount: Int
    let rawData: Data
}

enum MobileConfigError: LocalizedError {
    case invalidFormat(String)
    case missingRequiredField(String)
    case unsupportedPlatform(String)
    case uploadFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .unsupportedPlatform(let platform):
            return "Platform not supported: \(platform)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}

