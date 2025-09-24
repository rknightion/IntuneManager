import Foundation

/// Validates whether an assignment intent is supported for a given app type and target combination
struct AssignmentIntentValidator {

    /// Checks if an assignment intent is valid for a given app type and target combination
    static func isIntentValid(
        intent: AppAssignment.AssignmentIntent,
        appType: Application.AppType,
        targetType: AppAssignment.AssignmentTarget.TargetType
    ) -> Bool {
        // First check if the intent is valid for the app type
        guard isSupportedByAppType(intent: intent, appType: appType) else {
            return false
        }

        // Then check if the intent is valid for the target type (with app type context)
        return isSupportedByTarget(intent: intent, appType: appType, targetType: targetType)
    }

    /// Returns the valid intents for a given app type and target combination
    static func validIntents(
        for appType: Application.AppType,
        targetType: AppAssignment.AssignmentTarget.TargetType
    ) -> [AppAssignment.AssignmentIntent] {
        AppAssignment.AssignmentIntent.allCases.filter { intent in
            isIntentValid(intent: intent, appType: appType, targetType: targetType)
        }
    }

    /// Checks if an intent is supported by the app type
    private static func isSupportedByAppType(
        intent: AppAssignment.AssignmentIntent,
        appType: Application.AppType
    ) -> Bool {
        switch intent {
        case .available:
            // Available is supported for most app types
            return true

        case .availableWithoutEnrollment:
            // Available without enrollment is NOT supported for:
            // - VPP apps (iOS and macOS)
            // - Most managed store apps
            // - LOB apps that require installation
            switch appType {
            case .iosVppApp, .macOSVppApp:
                // VPP apps require enrollment for licensing
                return false
            case .managedIOSStoreApp, .managedMacOSStoreApp:
                // Managed store apps require enrollment
                return false
            case .iosLobApp, .macOSLobApp, .macOSDmgApp, .macOSPkgApp:
                // LOB apps typically require enrollment for installation
                return false
            case .webApp, .windowsWebApp:
                // Web apps can work without enrollment
                return true
            case .iosStoreApp:
                // Public store apps might work without enrollment
                return true
            default:
                // Conservative default - assume it's not supported
                return false
            }

        case .required:
            // Required is supported for all app types
            return true

        case .uninstall:
            // Uninstall is supported for apps that can be managed
            switch appType {
            case .webApp, .windowsWebApp:
                // Web apps can't be uninstalled (they're just links)
                return false
            case .iosStoreApp:
                // Built-in/store apps might not support uninstall
                return false
            default:
                return true
            }
        }
    }

    /// Checks if an intent is supported by the target type
    private static func isSupportedByTarget(
        intent: AppAssignment.AssignmentIntent,
        appType: Application.AppType,
        targetType: AppAssignment.AssignmentTarget.TargetType
    ) -> Bool {
        switch intent {
        case .available:
            // Available intent with AllDevices target:
            // - VPP apps CAN use Available with All Devices (they have licensing that supports it)
            // - Non-VPP apps CANNOT use Available with All Devices
            switch targetType {
            case .allDevices:
                // Check if this is a VPP app - they're allowed to use Available with All Devices
                switch appType {
                case .iosVppApp, .macOSVppApp:
                    return true  // VPP apps support Available for All Devices
                default:
                    return false  // Other apps don't support Available for All Devices
                }
            default:
                return true
            }

        case .availableWithoutEnrollment:
            // Available without enrollment doesn't make sense for device groups
            switch targetType {
            case .allDevices, .group, .exclusionGroup:
                // Device-based assignments require enrollment
                return false
            case .allUsers, .allLicensedUsers:
                // User-based assignments might support it
                return true
            default:
                return true
            }

        case .required, .uninstall:
            // Required and uninstall are generally supported for all targets
            return true
        }
    }

    /// Returns a user-friendly explanation for why an intent is not valid
    static func validationMessage(
        for intent: AppAssignment.AssignmentIntent,
        appType: Application.AppType,
        targetType: AppAssignment.AssignmentTarget.TargetType
    ) -> String? {
        guard !isIntentValid(intent: intent, appType: appType, targetType: targetType) else {
            return nil
        }

        // Check app type restrictions first
        if !isSupportedByAppType(intent: intent, appType: appType) {
            switch intent {
            case .availableWithoutEnrollment:
                switch appType {
                case .iosVppApp, .macOSVppApp:
                    return "VPP apps require device enrollment for licensing and cannot be assigned as 'Available without enrollment'"
                case .managedIOSStoreApp, .managedMacOSStoreApp:
                    return "Managed store apps require device enrollment and cannot be assigned as 'Available without enrollment'"
                case .iosLobApp, .macOSLobApp, .macOSDmgApp, .macOSPkgApp:
                    return "Line-of-business apps require device enrollment for installation"
                default:
                    return "\(appType.displayName) apps do not support 'Available without enrollment'"
                }

            case .uninstall:
                switch appType {
                case .webApp, .windowsWebApp:
                    return "Web apps cannot be uninstalled as they are just web links"
                case .iosStoreApp:
                    return "Built-in store apps cannot be uninstalled via Intune"
                default:
                    return "\(appType.displayName) apps do not support uninstall assignments"
                }

            default:
                return "\(intent.displayName) is not supported for \(appType.displayName) apps"
            }
        }

        // Check target type restrictions
        if !isSupportedByTarget(intent: intent, appType: appType, targetType: targetType) {
            switch intent {
            case .available:
                if targetType == .allDevices {
                    // More specific message based on app type
                    switch appType {
                    case .iosVppApp, .macOSVppApp:
                        // This should not happen for VPP apps, but just in case
                        return "Unexpected validation error for VPP app"
                    default:
                        return "'Available' intent is not supported for 'All Devices' target with non-VPP apps. Use 'Required' instead for device-wide deployments"
                    }
                }

            case .availableWithoutEnrollment:
                switch targetType {
                case .allDevices, .group, .exclusionGroup:
                    return "'Available without enrollment' cannot be used with device-based targets as devices must be enrolled to receive assignments"
                default:
                    break
                }

            default:
                break
            }

            return "\(intent.displayName) is not supported for \(targetType.displayName) targets"
        }

        return "This combination of intent and target is not supported"
    }

    /// Provides helpful suggestions for alternative intents
    static func suggestedIntents(
        for appType: Application.AppType,
        targetType: AppAssignment.AssignmentTarget.TargetType,
        preferredIntent: AppAssignment.AssignmentIntent? = nil
    ) -> [AppAssignment.AssignmentIntent] {
        let validIntents = validIntents(for: appType, targetType: targetType)

        guard let preferred = preferredIntent else {
            return validIntents
        }

        // If the preferred intent is valid, return it first
        if validIntents.contains(preferred) {
            return [preferred] + validIntents.filter { $0 != preferred }
        }

        // Otherwise, suggest alternatives based on the preferred intent
        switch preferred {
        case .availableWithoutEnrollment:
            // Suggest 'available' as an alternative
            if validIntents.contains(.available) {
                return [.available] + validIntents.filter { $0 != .available }
            }

        case .available:
            // Suggest 'required' as an alternative for device targets
            if targetType == .allDevices && validIntents.contains(.required) {
                return [.required] + validIntents.filter { $0 != .required }
            }

        default:
            break
        }

        return validIntents
    }
}

