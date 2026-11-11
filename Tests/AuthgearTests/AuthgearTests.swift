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
        let parsed = try XCTUnwrap(try App2AppAuthenticateRequest(url: request.toURL()))
        XCTAssertEqual(parsed.resource, "https://api.example.com")

        let withoutResource = App2AppAuthenticateOptions(
            authorizationEndpoint: "https://app.example.com/app2app",
            redirectUri: "https://other.example.com/cb"
        ).toRequest(clientID: "client", codeVerifier: CodeVerifier())
        let parsedWithout = try XCTUnwrap(try App2AppAuthenticateRequest(url: withoutResource.toURL()))
        XCTAssertNil(parsedWithout.resource)
    }

    private func bridgeReply(_ body: Any) -> NSDictionary? {
        switch AGWKWebViewBridgeMessages.action(for: body) {
        case let .reply(reply):
            return reply as NSDictionary
        }
    }

    func testBridgeCapabilities() {
        XCTAssertEqual(
            bridgeReply(#"{"id":"1","type":"bridge.capabilities"}"#),
            ["id": "1", "status": "ok", "capabilities": [String]()] as NSDictionary
        )
    }

    func testBridgeEnvelope() {
        let invalid = ["status": "error", "message": "invalid message"] as NSDictionary
        // Not JSON.
        XCTAssertEqual(bridgeReply("not json"), invalid)
        // Not a JSON object.
        XCTAssertEqual(bridgeReply(#"["1"]"#), invalid)
        // Not a string.
        XCTAssertEqual(bridgeReply(["id": "1", "type": "bridge.capabilities"]), invalid)
        // Missing id.
        XCTAssertEqual(bridgeReply(#"{"type":"bridge.capabilities"}"#), invalid)
        // id is not a string.
        XCTAssertEqual(bridgeReply(#"{"id":1,"type":"bridge.capabilities"}"#), invalid)
        // Unknown type.
        XCTAssertEqual(
            bridgeReply(#"{"id":"2","type":"webview.close"}"#),
            ["id": "2", "status": "unsupported"] as NSDictionary
        )
        // Missing type.
        XCTAssertEqual(
            bridgeReply(#"{"id":"3"}"#),
            ["id": "3", "status": "unsupported"] as NSDictionary
        )
        // Unknown fields are ignored.
        XCTAssertEqual(
            bridgeReply(#"{"id":"4","type":"bridge.capabilities","extra":true}"#)?["status"] as? String,
            "ok"
        )
    }

    func testBridgeEncodeReply() throws {
        for status in ["ok", "unsupported", "error", "no_credential", "cancelled"] {
            let text = AGWKWebViewBridgeMessages.encodeReply(["id": "1", "status": status])
            let decoded = try XCTUnwrap(
                try JSONSerialization.jsonObject(with: Data(text.utf8)) as? NSDictionary
            )
            XCTAssertEqual(decoded, ["id": "1", "status": status] as NSDictionary)
        }
    }

    func testBridgeIsAllowedOrigin() throws {
        func isAllowed(_ scheme: String, _ host: String, _ port: Int, _ allowed: String) throws -> Bool {
            try AGWKWebViewBridgeMessages.isAllowedOrigin(
                scheme: scheme,
                host: host,
                port: port,
                allowedOrigins: [XCTUnwrap(URL(string: allowed))]
            )
        }
        // Same origin. WKSecurityOrigin.port is 0 for the default port.
        XCTAssertTrue(try isAllowed("https", "auth.example.com", 0, "https://auth.example.com"))
        // Different host.
        XCTAssertFalse(try isAllowed("https", "evil.example.com", 0, "https://auth.example.com"))
        // Different scheme.
        XCTAssertFalse(try isAllowed("http", "auth.example.com", 0, "https://auth.example.com"))
        // An explicit default port equals no port, on both sides.
        XCTAssertTrue(try isAllowed("https", "auth.example.com", 443, "https://auth.example.com"))
        XCTAssertTrue(try isAllowed("https", "auth.example.com", 0, "https://auth.example.com:443"))
        XCTAssertTrue(try isAllowed("http", "localhost", 0, "http://localhost:80"))
        // Different port.
        XCTAssertFalse(try isAllowed("https", "auth.example.com", 8443, "https://auth.example.com"))
        XCTAssertFalse(try isAllowed("http", "localhost", 3001, "http://localhost:3000"))
        XCTAssertTrue(try isAllowed("http", "localhost", 3000, "http://localhost:3000"))
        // The path and query of an allowed URL are ignored.
        XCTAssertTrue(try isAllowed(
            "https",
            "auth.example.com",
            0,
            "https://auth.example.com/oauth2/authorize?client_id=abc#fragment"
        ))
        // No allowed origins.
        XCTAssertFalse(AGWKWebViewBridgeMessages.isAllowedOrigin(
            scheme: "https",
            host: "auth.example.com",
            port: 0,
            allowedOrigins: []
        ))
    }

    static var allTests = [
        ("testExample", testExample),
        ("testGetAuthenticationScopes", testGetAuthenticationScopes),
        ("testAuthenticateOptionsDefaults", testAuthenticateOptionsDefaults),
        ("testApp2AppAuthenticateRequestResource", testApp2AppAuthenticateRequestResource),
        ("testBridgeCapabilities", testBridgeCapabilities),
        ("testBridgeEnvelope", testBridgeEnvelope),
        ("testBridgeEncodeReply", testBridgeEncodeReply),
        ("testBridgeIsAllowedOrigin", testBridgeIsAllowedOrigin)
    ]
}
