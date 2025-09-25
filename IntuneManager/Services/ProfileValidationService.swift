import Foundation

@MainActor
final class ProfileValidationService {
    static let shared = ProfileValidationService()

    private init() {}

    // MARK: - Profile Validation

    func validateProfile(_ profile: ConfigurationProfile) -> ProfileValidationReport {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        // Validate basic properties
        if profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                field: "displayName",
                message: "Profile name cannot be empty",
                severity: .critical
            ))
        }

        if profile.displayName.count > 100 {
            warnings.append(ValidationWarning(
                field: "displayName",
                message: "Profile name is very long and may be truncated in some views"
            ))
        }

        // Validate platform-specific requirements
        validatePlatformRequirements(profile, errors: &errors, warnings: &warnings)

        // Validate settings if present
        if let settings = profile.settings {
            validateSettings(settings, platform: profile.platformType, errors: &errors, warnings: &warnings)
        }

        // Validate assignments
        if let assignments = profile.assignments {
            validateAssignments(assignments, errors: &errors, warnings: &warnings)
        }

        return ProfileValidationReport(
            profileId: profile.id,
            profileName: profile.displayName,
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings,
            validatedAt: Date()
        )
    }

    // MARK: - Conflict Detection

    func detectConflicts(
        for profile: ConfigurationProfile,
        against existingProfiles: [ConfigurationProfile]
    ) -> ConflictDetectionReport {
        var conflicts: [ProfileConflict] = []

        // Filter to profiles targeting the same platform
        let relevantProfiles = existingProfiles.filter { existing in
            existing.id != profile.id &&
            existing.platformType == profile.platformType
        }

        for existingProfile in relevantProfiles {
            // Check for assignment overlaps
            if let assignmentConflict = detectAssignmentConflict(profile, existingProfile) {
                conflicts.append(assignmentConflict)
            }

            // Check for setting conflicts
            if let settingConflicts = detectSettingConflicts(profile, existingProfile) {
                conflicts.append(contentsOf: settingConflicts)
            }

            // Check for duplicate profiles
            if isDuplicateProfile(profile, existingProfile) {
                conflicts.append(ProfileConflict(
                    type: .duplicate,
                    conflictingProfileId: existingProfile.id,
                    conflictingProfileName: existingProfile.displayName,
                    description: "Profile appears to be a duplicate of '\(existingProfile.displayName)'",
                    resolution: "Consider merging these profiles or removing the duplicate",
                    severity: .warning
                ))
            }
        }

        return ConflictDetectionReport(
            profileId: profile.id,
            profileName: profile.displayName,
            conflicts: conflicts,
            hasConflicts: !conflicts.isEmpty,
            analyzedAt: Date()
        )
    }

    // MARK: - Bulk Validation

    func validateProfiles(_ profiles: [ConfigurationProfile]) -> BulkValidationReport {
        var reports: [ProfileValidationReport] = []
        var overallErrors = 0
        var overallWarnings = 0

        for profile in profiles {
            let report = validateProfile(profile)
            reports.append(report)
            overallErrors += report.errors.count
            overallWarnings += report.warnings.count
        }

        // Detect conflicts between all profiles
        var conflictReports: [ConflictDetectionReport] = []
        for profile in profiles {
            let otherProfiles = profiles.filter { $0.id != profile.id }
            let conflictReport = detectConflicts(for: profile, against: otherProfiles)
            if conflictReport.hasConflicts {
                conflictReports.append(conflictReport)
            }
        }

        return BulkValidationReport(
            validationReports: reports,
            conflictReports: conflictReports,
            totalProfiles: profiles.count,
            validProfiles: reports.filter { $0.isValid }.count,
            totalErrors: overallErrors,
            totalWarnings: overallWarnings,
            totalConflicts: conflictReports.reduce(0) { $0 + $1.conflicts.count },
            validatedAt: Date()
        )
    }

    // MARK: - Private Helpers

    private func validatePlatformRequirements(
        _ profile: ConfigurationProfile,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        switch profile.platformType {
        case .iOS:
            if profile.profileType == .custom {
                warnings.append(ValidationWarning(
                    field: "profileType",
                    message: "Custom profiles for iOS should be thoroughly tested on target devices"
                ))
            }
        case .macOS:
            if profile.profileType == .settingsCatalog && profile.templateId == nil {
                warnings.append(ValidationWarning(
                    field: "template",
                    message: "Settings Catalog profile without template may have limited functionality"
                ))
            }
        case .android, .androidEnterprise, .androidWorkProfile:
            if profile.assignments?.contains(where: { $0.target.type == .allDevices }) == true {
                warnings.append(ValidationWarning(
                    field: "assignments",
                    message: "Android profiles assigned to all devices may not apply to non-enrolled devices"
                ))
            }
        case .windows10:
            // Windows-specific validations
            break
        }
    }

    private func validateSettings(
        _ settings: [ConfigurationSetting],
        platform: ConfigurationProfile.PlatformType,
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        // Check for duplicate settings
        let settingIds = settings.map { $0.settingDefinitionId }
        let duplicates = Dictionary(grouping: settingIds) { $0 }
            .filter { $1.count > 1 }
            .keys

        for duplicate in duplicates {
            errors.append(ValidationError(
                field: "settings",
                message: "Duplicate setting detected: \(duplicate)",
                severity: .high
            ))
        }

        // Validate required settings
        let requiredSettings = settings.filter { $0.isRequired }
        for setting in requiredSettings {
            if setting.value == nil || setting.value?.isEmpty == true {
                errors.append(ValidationError(
                    field: "settings.\(setting.settingDefinitionId)",
                    message: "Required setting '\(setting.displayName)' has no value",
                    severity: .high
                ))
            }
        }
    }

    private func validateAssignments(
        _ assignments: [ConfigurationAssignment],
        errors: inout [ValidationError],
        warnings: inout [ValidationWarning]
    ) {
        // Check for conflicting assignments
        let hasAllUsers = assignments.contains { $0.target.type == .allUsers }
        let hasAllDevices = assignments.contains { $0.target.type == .allDevices }

        if hasAllUsers && hasAllDevices {
            errors.append(ValidationError(
                field: "assignments",
                message: "Profile cannot be assigned to both 'All Users' and 'All Devices'",
                severity: .high
            ))
        }

        // Check for redundant group assignments
        if (hasAllUsers || hasAllDevices) && assignments.contains(where: { $0.target.type == .group }) {
            warnings.append(ValidationWarning(
                field: "assignments",
                message: "Group assignments are redundant when profile is assigned to all users or devices"
            ))
        }

        // Check for exclusion without inclusion
        let hasExclusions = assignments.contains { $0.target.type == .exclusionGroup }
        let hasInclusions = assignments.contains { assignment in
            assignment.target.type == .group ||
            assignment.target.type == .allUsers ||
            assignment.target.type == .allDevices
        }

        if hasExclusions && !hasInclusions {
            errors.append(ValidationError(
                field: "assignments",
                message: "Exclusion groups require at least one inclusion assignment",
                severity: .critical
            ))
        }
    }

    private func detectAssignmentConflict(
        _ profile1: ConfigurationProfile,
        _ profile2: ConfigurationProfile
    ) -> ProfileConflict? {
        guard let assignments1 = profile1.assignments,
              let assignments2 = profile2.assignments,
              !assignments1.isEmpty && !assignments2.isEmpty else {
            return nil
        }

        // Check if both target the same groups
        let groups1 = Set(assignments1.compactMap { $0.target.groupId })
        let groups2 = Set(assignments2.compactMap { $0.target.groupId })

        let overlappingGroups = groups1.intersection(groups2)

        if !overlappingGroups.isEmpty {
            return ProfileConflict(
                type: .assignmentOverlap,
                conflictingProfileId: profile2.id,
                conflictingProfileName: profile2.displayName,
                description: "Both profiles target the same \(overlappingGroups.count) group(s)",
                resolution: "Review assignments to ensure intended behavior",
                severity: .medium
            )
        }

        // Check if both target all users/devices
        let bothTargetAllUsers = assignments1.contains { $0.target.type == .allUsers } &&
                                 assignments2.contains { $0.target.type == .allUsers }
        let bothTargetAllDevices = assignments1.contains { $0.target.type == .allDevices } &&
                                   assignments2.contains { $0.target.type == .allDevices }

        if bothTargetAllUsers || bothTargetAllDevices {
            return ProfileConflict(
                type: .assignmentOverlap,
                conflictingProfileId: profile2.id,
                conflictingProfileName: profile2.displayName,
                description: "Both profiles target \(bothTargetAllUsers ? "all users" : "all devices")",
                resolution: "Consider consolidating these profiles or using exclusion groups",
                severity: .high
            )
        }

        return nil
    }

    private func detectSettingConflicts(
        _ profile1: ConfigurationProfile,
        _ profile2: ConfigurationProfile
    ) -> [ProfileConflict]? {
        guard let settings1 = profile1.settings,
              let settings2 = profile2.settings,
              !settings1.isEmpty && !settings2.isEmpty else {
            return nil
        }

        var conflicts: [ProfileConflict] = []

        let settingIds1 = Set(settings1.map { $0.settingDefinitionId })
        let settingIds2 = Set(settings2.map { $0.settingDefinitionId })

        let overlappingSettings = settingIds1.intersection(settingIds2)

        for settingId in overlappingSettings {
            let setting1 = settings1.first { $0.settingDefinitionId == settingId }
            let setting2 = settings2.first { $0.settingDefinitionId == settingId }

            if setting1?.value != setting2?.value {
                conflicts.append(ProfileConflict(
                    type: .settingConflict,
                    conflictingProfileId: profile2.id,
                    conflictingProfileName: profile2.displayName,
                    description: "Conflicting value for setting '\(setting1?.displayName ?? settingId)'",
                    resolution: "Ensure consistent settings across profiles targeting the same devices",
                    severity: .high
                ))
            }
        }

        return conflicts.isEmpty ? nil : conflicts
    }

    private func isDuplicateProfile(
        _ profile1: ConfigurationProfile,
        _ profile2: ConfigurationProfile
    ) -> Bool {
        // Check if profiles are essentially duplicates
        let samePlatform = profile1.platformType == profile2.platformType
        let sameType = profile1.profileType == profile2.profileType
        let similarName = profile1.displayName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines) ==
            profile2.displayName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return samePlatform && sameType && similarName
    }
}

// MARK: - Data Models

struct ProfileValidationReport {
    let profileId: String
    let profileName: String
    let isValid: Bool
    let errors: [ValidationError]
    let warnings: [ValidationWarning]
    let validatedAt: Date
}

struct ValidationError {
    enum Severity {
        case low, medium, high, critical
    }

    let field: String
    let message: String
    let severity: Severity
}

struct ValidationWarning {
    let field: String
    let message: String
}

struct ConflictDetectionReport {
    let profileId: String
    let profileName: String
    let conflicts: [ProfileConflict]
    let hasConflicts: Bool
    let analyzedAt: Date
}

struct ProfileConflict: Identifiable {
    let id = UUID()

    enum ConflictType {
        case assignmentOverlap
        case settingConflict
        case duplicate
    }

    enum Severity {
        case low, medium, high, warning
    }

    let type: ConflictType
    let conflictingProfileId: String
    let conflictingProfileName: String
    let description: String
    let resolution: String
    let severity: Severity
}

struct BulkValidationReport {
    let validationReports: [ProfileValidationReport]
    let conflictReports: [ConflictDetectionReport]
    let totalProfiles: Int
    let validProfiles: Int
    let totalErrors: Int
    let totalWarnings: Int
    let totalConflicts: Int
    let validatedAt: Date
}