import Foundation

// MARK: - Android Store App Request

/// Request model for creating an Android Store app in Intune
struct AndroidStoreAppRequest: Encodable, Sendable {
    let displayName: String
    let description: String?
    let publisher: String
    let packageId: String
    let appStoreUrl: String?
    let minimumSupportedOperatingSystem: AndroidMinimumOperatingSystem?
    let isFeatured: Bool
    let informationUrl: String?
    let privacyInformationUrl: String?
    let developer: String?
    let owner: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case displayName
        case description
        case publisher
        case packageId
        case appStoreUrl
        case minimumSupportedOperatingSystem
        case isFeatured
        case informationUrl
        case privacyInformationUrl
        case developer
        case owner
        case notes
    }

    init(displayName: String,
         description: String? = nil,
         publisher: String,
         packageId: String,
         appStoreUrl: String? = nil,
         minimumSupportedOperatingSystem: AndroidMinimumOperatingSystem? = nil,
         isFeatured: Bool = false,
         informationUrl: String? = nil,
         privacyInformationUrl: String? = nil,
         developer: String? = nil,
         owner: String? = nil,
         notes: String? = nil) {
        self.displayName = displayName
        self.description = description
        self.publisher = publisher
        self.packageId = packageId
        self.appStoreUrl = appStoreUrl
        self.minimumSupportedOperatingSystem = minimumSupportedOperatingSystem
        self.isFeatured = isFeatured
        self.informationUrl = informationUrl
        self.privacyInformationUrl = privacyInformationUrl
        self.developer = developer
        self.owner = owner
        self.notes = notes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("#microsoft.graph.androidStoreApp", forKey: .odataType)
        try container.encode(displayName, forKey: .displayName)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(publisher, forKey: .publisher)
        try container.encode(packageId, forKey: .packageId)
        try container.encodeIfPresent(appStoreUrl, forKey: .appStoreUrl)
        try container.encodeIfPresent(minimumSupportedOperatingSystem, forKey: .minimumSupportedOperatingSystem)
        try container.encode(isFeatured, forKey: .isFeatured)
        try container.encodeIfPresent(informationUrl, forKey: .informationUrl)
        try container.encodeIfPresent(privacyInformationUrl, forKey: .privacyInformationUrl)
        try container.encodeIfPresent(developer, forKey: .developer)
        try container.encodeIfPresent(owner, forKey: .owner)
        try container.encodeIfPresent(notes, forKey: .notes)
    }

    /// Validates the request data
    func validate() throws {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AndroidAppValidationError.emptyDisplayName
        }

        guard !publisher.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AndroidAppValidationError.emptyPublisher
        }

        try ValidationHelper.validatePackageId(packageId)

        if let url = appStoreUrl {
            try ValidationHelper.validateURL(url, fieldName: "App Store URL")
        }

        if let url = informationUrl {
            try ValidationHelper.validateURL(url, fieldName: "Information URL")
        }

        if let url = privacyInformationUrl {
            try ValidationHelper.validateURL(url, fieldName: "Privacy Information URL")
        }
    }
}

// MARK: - Android Enterprise System App Request

/// Request model for creating an Android Enterprise System app in Intune
/// Uses androidStoreApp type with minimal fields for pre-installed system apps
struct AndroidManagedStoreAppRequest: Encodable, Sendable {  // Keep the name for compatibility
    let displayName: String
    let publisher: String
    let packageId: String

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case displayName
        case publisher
        case packageId
    }

    init(displayName: String,
         publisher: String,
         packageId: String) {
        self.displayName = displayName
        self.publisher = publisher
        self.packageId = packageId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Use androidStoreApp for system apps, not androidManagedStoreApp
        try container.encode("#microsoft.graph.androidStoreApp", forKey: .odataType)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(publisher, forKey: .publisher)
        try container.encode(packageId, forKey: .packageId)
    }

    /// Validates the request data
    func validate() throws {
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AndroidAppValidationError.emptyDisplayName
        }

        guard !publisher.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw AndroidAppValidationError.emptyPublisher
        }

        try ValidationHelper.validatePackageId(packageId)
    }
}

// MARK: - Android Minimum Operating System

struct AndroidMinimumOperatingSystem: Encodable, Sendable {
    let v4_0: Bool?
    let v4_0_3: Bool?
    let v4_1: Bool?
    let v4_2: Bool?
    let v4_3: Bool?
    let v4_4: Bool?
    let v5_0: Bool?
    let v5_1: Bool?
    let v6_0: Bool?
    let v7_0: Bool?
    let v7_1: Bool?
    let v8_0: Bool?
    let v8_1: Bool?
    let v9_0: Bool?
    let v10_0: Bool?
    let v11_0: Bool?
    let v12_0: Bool?
    let v13_0: Bool?
    let v14_0: Bool?
    let v15_0: Bool?

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case v4_0, v4_0_3, v4_1, v4_2, v4_3, v4_4
        case v5_0, v5_1, v6_0, v7_0, v7_1
        case v8_0, v8_1, v9_0, v10_0, v11_0
        case v12_0, v13_0, v14_0, v15_0
    }

    /// Creates a minimum OS requirement for a specific Android version
    static func forVersion(_ version: String) -> AndroidMinimumOperatingSystem {
        let normalized = version.replacingOccurrences(of: ".", with: "_")

        return AndroidMinimumOperatingSystem(
            v4_0: normalized == "4_0" ? true : nil,
            v4_0_3: normalized == "4_0_3" ? true : nil,
            v4_1: normalized == "4_1" ? true : nil,
            v4_2: normalized == "4_2" ? true : nil,
            v4_3: normalized == "4_3" ? true : nil,
            v4_4: normalized == "4_4" ? true : nil,
            v5_0: normalized == "5_0" ? true : nil,
            v5_1: normalized == "5_1" ? true : nil,
            v6_0: normalized == "6_0" ? true : nil,
            v7_0: normalized == "7_0" ? true : nil,
            v7_1: normalized == "7_1" ? true : nil,
            v8_0: normalized == "8_0" ? true : nil,
            v8_1: normalized == "8_1" ? true : nil,
            v9_0: normalized == "9_0" ? true : nil,
            v10_0: normalized == "10_0" ? true : nil,
            v11_0: normalized == "11_0" ? true : nil,
            v12_0: normalized == "12_0" ? true : nil,
            v13_0: normalized == "13_0" ? true : nil,
            v14_0: normalized == "14_0" ? true : nil,
            v15_0: normalized == "15_0" ? true : nil
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("microsoft.graph.androidMinimumOperatingSystem", forKey: .odataType)
        try container.encodeIfPresent(v4_0, forKey: .v4_0)
        try container.encodeIfPresent(v4_0_3, forKey: .v4_0_3)
        try container.encodeIfPresent(v4_1, forKey: .v4_1)
        try container.encodeIfPresent(v4_2, forKey: .v4_2)
        try container.encodeIfPresent(v4_3, forKey: .v4_3)
        try container.encodeIfPresent(v4_4, forKey: .v4_4)
        try container.encodeIfPresent(v5_0, forKey: .v5_0)
        try container.encodeIfPresent(v5_1, forKey: .v5_1)
        try container.encodeIfPresent(v6_0, forKey: .v6_0)
        try container.encodeIfPresent(v7_0, forKey: .v7_0)
        try container.encodeIfPresent(v7_1, forKey: .v7_1)
        try container.encodeIfPresent(v8_0, forKey: .v8_0)
        try container.encodeIfPresent(v8_1, forKey: .v8_1)
        try container.encodeIfPresent(v9_0, forKey: .v9_0)
        try container.encodeIfPresent(v10_0, forKey: .v10_0)
        try container.encodeIfPresent(v11_0, forKey: .v11_0)
        try container.encodeIfPresent(v12_0, forKey: .v12_0)
        try container.encodeIfPresent(v13_0, forKey: .v13_0)
        try container.encodeIfPresent(v14_0, forKey: .v14_0)
        try container.encodeIfPresent(v15_0, forKey: .v15_0)
    }
}

// MARK: - Validation Helpers

enum AndroidAppValidationError: LocalizedError {
    case emptyDisplayName
    case emptyPublisher
    case invalidPackageId(String)
    case invalidURL(String, String)

    var errorDescription: String? {
        switch self {
        case .emptyDisplayName:
            return "Display name cannot be empty"
        case .emptyPublisher:
            return "Publisher cannot be empty"
        case .invalidPackageId(let packageId):
            return "Invalid package ID '\(packageId)'. Package ID must follow the format 'com.example.app' with lowercase letters, numbers, and underscores only."
        case .invalidURL(let fieldName, let url):
            return "\(fieldName) '\(url)' is not a valid URL"
        }
    }
}

struct ValidationHelper {
    /// Validates Android package ID format (e.g., com.example.app)
    static func validatePackageId(_ packageId: String) throws {
        let trimmed = packageId.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            throw AndroidAppValidationError.invalidPackageId(packageId)
        }

        // Package ID pattern: starts with lowercase letter, followed by segments separated by dots
        // Each segment: lowercase letter followed by lowercase letters/numbers/underscores
        let pattern = "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        guard regex.firstMatch(in: trimmed, options: [], range: range) != nil else {
            throw AndroidAppValidationError.invalidPackageId(packageId)
        }
    }

    /// Validates URL format
    static func validateURL(_ urlString: String, fieldName: String) throws {
        let trimmed = urlString.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            return // Empty URLs are allowed for optional fields
        }

        guard let url = URL(string: trimmed),
              let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()) else {
            throw AndroidAppValidationError.invalidURL(fieldName, urlString)
        }
    }
}
