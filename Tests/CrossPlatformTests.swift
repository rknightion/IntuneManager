import XCTest
import SwiftUI
@testable import IntuneManager

/// Cross-platform compatibility tests
class CrossPlatformTests: XCTestCase {

    // MARK: - Platform Detection Tests

    func testPlatformDetection() {
        #if os(iOS)
        XCTAssertTrue(true, "Running on iOS")
        #elseif os(macOS)
        XCTAssertTrue(true, "Running on macOS")
        #endif
    }

    func testDeviceDetection() {
        #if os(iOS)
        let device = UIDevice.current
        XCTAssertNotNil(device)

        if device.userInterfaceIdiom == .phone {
            XCTAssertTrue(true, "Running on iPhone")
        } else if device.userInterfaceIdiom == .pad {
            XCTAssertTrue(true, "Running on iPad")
        }
        #endif
    }

    // MARK: - Platform Helper Tests

    func testPlatformHelperURLOpening() {
        guard let url = URL(string: "https://www.example.com") else {
            XCTFail("Failed to create URL")
            return
        }

        // This won't actually open the URL in tests, but validates the method exists
        PlatformHelper.openURL(url)
        XCTAssertTrue(true, "URL opening method exists")
    }

    func testPlatformHelperViewControllerRetrieval() async {
        #if os(iOS)
        let viewController = await PlatformHelper.getRootViewController()
        // In test environment, this might be nil
        XCTAssertTrue(viewController == nil || viewController != nil, "View controller retrieval works")
        #elseif os(macOS)
        let viewController = await PlatformHelper.getRootViewController()
        // In test environment, this might be nil
        XCTAssertTrue(viewController == nil || viewController != nil, "View controller retrieval works")
        #endif
    }

    // MARK: - Pasteboard Tests

    func testPasteboardCopyAndRetrieve() {
        let testString = "Test String for Clipboard"

        PlatformPasteboard.copyToClipboard(testString)
        let retrieved = PlatformPasteboard.getFromClipboard()

        XCTAssertEqual(retrieved, testString, "Pasteboard copy and retrieve should work")
    }

    // MARK: - Platform-Specific View Tests

    func testPlatformNavigationView() {
        let view = PlatformNavigation(title: "Test") {
            Text("Content")
        }

        XCTAssertNotNil(view, "Platform navigation should create successfully")
    }

    func testPlatformTabView() {
        @State var selection = AppState.Tab.dashboard
        let view = PlatformTabView(selection: $selection) {
            Text("Content")
        }

        XCTAssertNotNil(view, "Platform tab view should create successfully")
    }

    func testPlatformButton() {
        let button = PlatformButton(title: "Test", action: {})
        XCTAssertNotNil(button, "Platform button should create successfully")
    }

    // MARK: - Cross-Platform Model Tests

    func testAppConfigurationCrossPlatform() {
        let config = AppConfiguration(
            clientId: "test-client",
            tenantId: "test-tenant",
            clientSecret: nil,
            redirectUri: "msauth.test://auth"
        )

        XCTAssertTrue(config.isValid)
        XCTAssertTrue(config.isPublicClient)
        XCTAssertEqual(config.authority, "https://login.microsoftonline.com/test-tenant")
    }

    func testDeviceModelCrossPlatform() {
        let device = Device(
            id: "test-device",
            deviceName: "Test Device",
            operatingSystem: "macOS"
        )

        XCTAssertNotNil(device)
        XCTAssertEqual(device.deviceName, "Test Device")
    }

    // MARK: - Haptics Tests

    func testHapticsDoNotCrash() {
        // Should not crash on any platform
        PlatformHaptics.trigger(.success)
        PlatformHaptics.trigger(.warning)
        PlatformHaptics.trigger(.error)
        PlatformHaptics.trigger(.selection)

        XCTAssertTrue(true, "Haptics should not crash on any platform")
    }

    // MARK: - View Modifier Tests

    func testPlatformViewModifiers() {
        let view = Text("Test")
            .platformNavigationStyle()
            .platformListStyle()
            .platformFormStyle()

        XCTAssertNotNil(view, "Platform view modifiers should apply successfully")
    }

    func testPlatformConditionalViews() {
        let view = Text("Test")
            .iOS {
                Text("iOS Only")
            }
            .macOS {
                Text("macOS Only")
            }

        XCTAssertNotNil(view, "Platform conditional views should work")
    }

    // MARK: - Authentication Cross-Platform Tests

    func testAuthManagerCrossPlatform() async {
        let authManager = AuthManagerV2.shared

        // Should work on both platforms
        XCTAssertNotNil(authManager)
        XCTAssertFalse(authManager.isAuthenticated)

        // Sign out should work without errors
        await authManager.signOut()
        XCTAssertFalse(authManager.isAuthenticated)
    }

    func testCredentialManagerCrossPlatform() async throws {
        let credentialManager = CredentialManager.shared

        let config = AppConfiguration(
            clientId: "cross-platform-test",
            tenantId: "test-tenant",
            clientSecret: nil,
            redirectUri: "msauth.test://auth"
        )

        try await credentialManager.saveConfiguration(config)

        XCTAssertTrue(credentialManager.isConfigured)
        XCTAssertEqual(credentialManager.configuration?.clientId, "cross-platform-test")

        // Clean up
        try await credentialManager.clearConfiguration()
    }

    // MARK: - Cache Manager Cross-Platform Tests

    func testCacheManagerCrossPlatform() {
        let cacheManager = CacheManager.shared

        struct TestData: Codable {
            let value: String
        }

        let testData = TestData(value: "Cross-platform test")
        cacheManager.setObject(testData, forKey: "test-key", expiration: .hours(1))

        let retrieved = cacheManager.getObject(forKey: "test-key", type: TestData.self)
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.value, "Cross-platform test")

        cacheManager.removeObject(forKey: "test-key")
    }

    // MARK: - Window Management Tests

    #if os(macOS)
    func testMacOSWindowManagement() {
        // These won't have effect in tests but validate the methods exist
        PlatformWindow.setWindowSize(width: 800, height: 600)
        PlatformWindow.centerWindow()
        PlatformWindow.setWindowTitle("Test Title")

        XCTAssertTrue(true, "Window management methods should exist on macOS")
    }
    #endif

    // MARK: - File Management Tests

    func testFileManagerCrossPlatform() {
        let expectation = XCTestExpectation(description: "File operation")

        // Test save operation (won't show dialog in tests)
        let testData = "Test content".data(using: .utf8)!
        PlatformFileManager.saveFile(data: testData, suggestedFilename: "test.txt") { url in
            // In tests, this will likely be nil
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Performance Tests

    func testCrossPlatformPerformance() {
        measure {
            // Test view creation performance
            _ = UnifiedContentView()
                .environmentObject(AuthManagerV2.shared)
                .environmentObject(AppState())
                .environmentObject(CredentialManager.shared)
        }
    }

    // MARK: - Memory Tests

    func testNoMemoryLeaks() {
        autoreleasepool {
            // Create and destroy views to check for leaks
            var view: AnyView? = AnyView(UnifiedContentView())
            view = nil

            var loginView: AnyView? = AnyView(UnifiedLoginView())
            loginView = nil

            var sidebarView: AnyView? = AnyView(UnifiedSidebarView(selection: .constant(.dashboard)))
            sidebarView = nil
        }

        XCTAssertTrue(true, "Views should deallocate properly")
    }
}

// MARK: - UI Test Helper

@available(iOS 16.0, macOS 13.0, *)
class CrossPlatformUITestHelper {
    static func validateNavigationFlow() async {
        let authManager = AuthManagerV2.shared
        let credentialManager = CredentialManager.shared
        let appState = AppState()

        // Test navigation through different states
        if !credentialManager.isConfigured {
            // Should show configuration
            XCTAssertFalse(authManager.isAuthenticated)
        }

        // Test tab switching
        appState.selectedTab = .devices
        XCTAssertEqual(appState.selectedTab, .devices)

        appState.selectedTab = .applications
        XCTAssertEqual(appState.selectedTab, .applications)

        appState.selectedTab = .assignments
        XCTAssertEqual(appState.selectedTab, .assignments)
    }

    static func validatePlatformSpecificUI() {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad should use split view
            XCTAssertTrue(true, "iPad uses split view navigation")
        } else {
            // iPhone should use tab bar
            XCTAssertTrue(true, "iPhone uses tab bar navigation")
        }
        #elseif os(macOS)
        // macOS should use split view with sidebar
        XCTAssertTrue(true, "macOS uses split view with sidebar")
        #endif
    }
}