import Foundation
import UniformTypeIdentifiers

@MainActor
final class ProfileExportService {
    static let shared = ProfileExportService()

    private init() {}

    // MARK: - Export

    func exportProfile(_ profile: ConfigurationProfile) throws -> Data {
        let exportData = ProfileExportData(
            profile: profile,
            exportDate: Date(),
            version: "1.0"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(exportData)
    }

    func exportProfiles(_ profiles: [ConfigurationProfile]) throws -> Data {
        let exportData = ProfileBatchExportData(
            profiles: profiles,
            exportDate: Date(),
            version: "1.0",
            count: profiles.count
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(exportData)
    }

    // MARK: - Import

    func importProfile(from data: Data) throws -> ConfigurationProfile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportData = try decoder.decode(ProfileExportData.self, from: data)

        // Validate version compatibility
        guard isVersionCompatible(exportData.version) else {
            throw ProfileImportError.incompatibleVersion(exportData.version)
        }

        // Create new profile with new ID to avoid conflicts
        let importedProfile = exportData.profile
        importedProfile.id = UUID().uuidString
        importedProfile.createdDateTime = Date()
        importedProfile.lastModifiedDateTime = Date()

        // Clear assignments as they need to be reconfigured
        importedProfile.assignments = nil
        importedProfile.isAssigned = false

        return importedProfile
    }

    func importProfiles(from data: Data) throws -> [ConfigurationProfile] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let exportData = try decoder.decode(ProfileBatchExportData.self, from: data)

        // Validate version compatibility
        guard isVersionCompatible(exportData.version) else {
            throw ProfileImportError.incompatibleVersion(exportData.version)
        }

        // Process each profile
        return exportData.profiles.map { profile in
            // Create new profile with new ID to avoid conflicts
            profile.id = UUID().uuidString
            profile.createdDateTime = Date()
            profile.lastModifiedDateTime = Date()

            // Clear assignments as they need to be reconfigured
            profile.assignments = nil
            profile.isAssigned = false

            return profile
        }
    }

    // MARK: - File Operations

    func saveProfileToFile(_ profile: ConfigurationProfile, to url: URL) throws {
        let data = try exportProfile(profile)
        try data.write(to: url)

        Logger.shared.info("Exported profile '\(profile.displayName)' to \(url.lastPathComponent)", category: .data)
    }

    func loadProfileFromFile(at url: URL) throws -> ConfigurationProfile {
        let data = try Data(contentsOf: url)
        let profile = try importProfile(from: data)

        Logger.shared.info("Imported profile '\(profile.displayName)' from \(url.lastPathComponent)", category: .data)
        return profile
    }

    // MARK: - Validation

    func validateProfileData(_ data: Data) -> ProfileValidationResult {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            // Try to decode as single profile first
            if let _ = try? decoder.decode(ProfileExportData.self, from: data) {
                return ProfileValidationResult(
                    isValid: true,
                    profileCount: 1,
                    errors: []
                )
            }

            // Try to decode as batch
            if let batchData = try? decoder.decode(ProfileBatchExportData.self, from: data) {
                return ProfileValidationResult(
                    isValid: true,
                    profileCount: batchData.count,
                    errors: []
                )
            }

            return ProfileValidationResult(
                isValid: false,
                profileCount: 0,
                errors: ["Invalid profile data format"]
            )
        } catch {
            return ProfileValidationResult(
                isValid: false,
                profileCount: 0,
                errors: [error.localizedDescription]
            )
        }
    }

    private func isVersionCompatible(_ version: String) -> Bool {
        // For now, accept version 1.x
        return version.hasPrefix("1.")
    }
}

// MARK: - Export Data Models

struct ProfileExportData: Codable {
    let profile: ConfigurationProfile
    let exportDate: Date
    let version: String
    let metadata: ExportMetadata?

    init(profile: ConfigurationProfile, exportDate: Date, version: String) {
        self.profile = profile
        self.exportDate = exportDate
        self.version = version
        self.metadata = ExportMetadata(
            exportedBy: ProcessInfo.processInfo.userName,
            platform: "macOS",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
    }
}

struct ProfileBatchExportData: Codable {
    let profiles: [ConfigurationProfile]
    let exportDate: Date
    let version: String
    let count: Int
    let metadata: ExportMetadata?

    init(profiles: [ConfigurationProfile], exportDate: Date, version: String, count: Int) {
        self.profiles = profiles
        self.exportDate = exportDate
        self.version = version
        self.count = count
        self.metadata = ExportMetadata(
            exportedBy: ProcessInfo.processInfo.userName,
            platform: "macOS",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        )
    }
}

struct ExportMetadata: Codable {
    let exportedBy: String
    let platform: String
    let appVersion: String
}

// MARK: - Validation

struct ProfileValidationResult {
    let isValid: Bool
    let profileCount: Int
    let errors: [String]
}

// MARK: - Errors

enum ProfileImportError: LocalizedError {
    case incompatibleVersion(String)
    case invalidData
    case missingRequiredFields

    var errorDescription: String? {
        switch self {
        case .incompatibleVersion(let version):
            return "Incompatible export version: \(version). This file was exported from a newer version."
        case .invalidData:
            return "The file contains invalid or corrupted profile data."
        case .missingRequiredFields:
            return "The profile is missing required fields."
        }
    }
}

// MARK: - UTType Extension

extension UTType {
    static let configurationProfile = UTType(exportedAs: "com.intunemanager.configprofile")
}
