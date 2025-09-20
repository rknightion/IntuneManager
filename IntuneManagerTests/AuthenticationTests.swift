import XCTest
@testable import IntuneManager

final class AuthenticationInfrastructureTests: XCTestCase {
    func testConfigurationDefaults() {
        let config = MSALConfiguration.current
        XCTAssertEqual(config.authorityURL.host, "login.microsoftonline.com")
        XCTAssertFalse(MSALConfiguration.validate(), "Default configuration should require real credentials")
        XCTAssertEqual(config.scopes.count, 10)
    }

    func testGraphAPIErrorDescriptions() {
        XCTAssertEqual(GraphAPIError.invalidURL.errorDescription, "Invalid URL")

        let rateLimited = GraphAPIError.rateLimited(retryAfter: "30")
        XCTAssertTrue(rateLimited.errorDescription?.contains("30") == true)

        let serverError = GraphAPIError.serverError(message: "Oops", code: "500")
        XCTAssertTrue(serverError.errorDescription?.contains("Oops") == true)
    }
}
