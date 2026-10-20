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

    private func makeAuthenticateOptions(resource: String?, scopes: [String]?) -> AuthenticateOptions {
        AuthenticateOptions(
            redirectURI: "myapp://host/path",
            isSSOEnabled: false,
            preAuthenticatedURLEnabled: false,
            state: nil,
            xState: nil,
            prompt: nil,
            loginHint: nil,
            uiLocales: nil,
            colorScheme: nil,
            wechatRedirectURI: nil,
            page: nil,
            authenticationFlowGroup: nil,
            oauthProviderAlias: nil,
            resource: resource,
            scopes: scopes
        )
    }

    func testAuthenticateOptionsDefaults() {
        // The defaults are used when the call gives nothing.
        let withDefaults = makeAuthenticateOptions(resource: nil, scopes: nil)
            .toRequest(defaultResource: "https://default.example.com", defaultScopes: ["default:read"])
        XCTAssertEqual(withDefaults.resource, "https://default.example.com")
        XCTAssertEqual(
            withDefaults.scope,
            ["openid", "offline_access", "https://authgear.com/scopes/full-access", "default:read"]
        )

        // The call replaces the defaults without merging.
        let overridden = makeAuthenticateOptions(resource: "https://call.example.com", scopes: ["call:read"])
            .toRequest(defaultResource: "https://default.example.com", defaultScopes: ["default:read"])
        XCTAssertEqual(overridden.resource, "https://call.example.com")
        XCTAssertEqual(
            overridden.scope,
            ["openid", "offline_access", "https://authgear.com/scopes/full-access", "call:read"]
        )

        let none = makeAuthenticateOptions(resource: nil, scopes: nil)
            .toRequest(defaultResource: nil, defaultScopes: nil)
        XCTAssertNil(none.resource)
    }

    func testApp2AppAuthenticateRequestResource() throws {
        let options = App2AppAuthenticateOptions(
            authorizationEndpoint: "https://app.example.com/app2app",
            redirectUri: "https://other.example.com/cb",
            resource: "https://api.example.com"
        )
        let request = options.toRequest(clientID: "client", codeVerifier: CodeVerifier())
        XCTAssertEqual(request.resource, "https://api.example.com")
        let parsed = try XCTUnwrap(App2AppAuthenticateRequest(url: try request.toURL()))
        XCTAssertEqual(parsed.resource, "https://api.example.com")

        let withoutResource = App2AppAuthenticateOptions(
            authorizationEndpoint: "https://app.example.com/app2app",
            redirectUri: "https://other.example.com/cb"
        ).toRequest(clientID: "client", codeVerifier: CodeVerifier())
        let parsedWithout = try XCTUnwrap(App2AppAuthenticateRequest(url: try withoutResource.toURL()))
        XCTAssertNil(parsedWithout.resource)
    }

    static var allTests = [
        ("testExample", testExample),
        ("testGetAuthenticationScopes", testGetAuthenticationScopes),
        ("testAuthenticateOptionsDefaults", testAuthenticateOptionsDefaults),
        ("testApp2AppAuthenticateRequestResource", testApp2AppAuthenticateRequestResource)
    ]
}
