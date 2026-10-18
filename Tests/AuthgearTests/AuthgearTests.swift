@testable import Authgear
import XCTest

final class AuthgearTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
    }

    func testGetAuthenticationScopes() {
        XCTAssertEqual(
            getAuthenticationScopes(preAuthenticatedURLEnabled: false),
            ["openid", "offline_access", "https://authgear.com/scopes/full-access"]
        )
        XCTAssertEqual(
            getAuthenticationScopes(preAuthenticatedURLEnabled: true, additionalScopes: ["email", "profile"]),
            [
                "openid", "offline_access", "https://authgear.com/scopes/full-access",
                "device_sso", "https://authgear.com/scopes/pre-authenticated-url",
                "email", "profile"
            ]
        )
        // Scopes required by the SDK are never dropped or duplicated.
        XCTAssertEqual(
            getAuthenticationScopes(preAuthenticatedURLEnabled: false, additionalScopes: ["email", "openid", "email"]),
            ["openid", "offline_access", "https://authgear.com/scopes/full-access", "email"]
        )
    }

    static var allTests = [("testExample", testExample), ("testGetAuthenticationScopes", testGetAuthenticationScopes)]
}
