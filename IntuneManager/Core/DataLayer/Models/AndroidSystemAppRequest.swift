import Foundation

// MARK: - Android System App Request (Alternative approach)

/// Alternative request model for creating an Android System app
/// Uses androidStoreApp type with minimal fields
struct AndroidSystemAppRequest: Encodable, Sendable {
    let displayName: String
    let publisher: String
    let packageId: String

    enum CodingKeys: String, CodingKey {
        case odataType = "@odata.type"
        case displayName
        case publisher
        case packageId
    }

    init(packageId: String) {
        // Use packageId for all three fields as per Intune UI behavior
        self.displayName = packageId
        self.publisher = packageId
        self.packageId = packageId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Try androidStoreApp type instead
        try container.encode("#microsoft.graph.androidStoreApp", forKey: .odataType)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(publisher, forKey: .publisher)
        try container.encode(packageId, forKey: .packageId)
    }
}