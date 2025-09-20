import XCTest
@testable import IntuneManager

final class CrossPlatformModelTests: XCTestCase {
    func testAppStateTabSystemImages() {
        let mapping: [AppState.Tab: String] = [
            .dashboard: "chart.bar.fill",
            .devices: "iphone",
            .applications: "app.badge",
            .groups: "person.3",
            .assignments: "checklist",
            .settings: "gear"
        ]

        for tab in AppState.Tab.allCases {
            XCTAssertEqual(tab.systemImage, mapping[tab], "Unexpected system image for \(tab)")
        }
    }

    func testDeviceGroupDecodingFromMinimalPayload() throws {
        let json = """
        {
            "id": "group-1",
            "displayName": "Engineering",
            "securityEnabled": true,
            "mailEnabled": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let group = try decoder.decode(DeviceGroup.self, from: json)

        XCTAssertEqual(group.id, "group-1")
        XCTAssertEqual(group.displayName, "Engineering")
        XCTAssertTrue(group.securityEnabled)
        XCTAssertFalse(group.mailEnabled)
    }

    func testApplicationDecodingHandlesOdataType() throws {
        let json = """
        {
            "id": "app-1",
            "displayName": "Test App",
            "@odata.type": "#microsoft.graph.iosStoreApp",
            "createdDateTime": "2024-01-01T00:00:00Z",
            "lastModifiedDateTime": "2024-01-02T00:00:00Z",
            "isFeatured": false,
            "ignoreVersionDetection": false
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let application = try decoder.decode(Application.self, from: json)

        XCTAssertEqual(application.id, "app-1")
        XCTAssertEqual(application.displayName, "Test App")
        XCTAssertEqual(application.appType, .iOS)
    }
}
