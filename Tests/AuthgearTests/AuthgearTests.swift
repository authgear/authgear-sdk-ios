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
        case .getPublicKeyCredential:
            return nil
        }
    }

    private func bridgePublicKeyRequest(_ body: Any) -> AGWKWebViewBridgePublicKeyRequest? {
        switch AGWKWebViewBridgeMessages.action(for: body) {
        case .reply:
            return nil
        case let .getPublicKeyCredential(id, request):
            XCTAssertEqual(id, "2")
            return request
        }
    }

    func testBridgeCapabilities() {
        XCTAssertEqual(
            bridgeReply(#"{"id":"1","type":"bridge.capabilities"}"#),
            [
                "id": "1",
                "status": "ok",
                "capabilities": ["credentials.get", "credentials.get:publicKey", "credentials.get:immediate"]
            ] as NSDictionary
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

    func testBridgeCredentialsGet() throws {
        // The challenge "3PzO..." has no padding; it decodes to 32 bytes.
        let challenge = "3PzOb9VvB54BIdrOC5b88ewjYt1wEOmKbCd0IM8FQSA"
        let challengeData = try XCTUnwrap(Data(base64Encoded: "3PzOb9VvB54BIdrOC5b88ewjYt1wEOmKbCd0IM8FQSA="))
        XCTAssertEqual(challengeData.count, 32)

        // Valid. The login page sends allowCredentials empty. timeout and extensions are ignored.
        XCTAssertEqual(
            bridgePublicKeyRequest("""
            {"id":"2","type":"credentials.get","mediation":"immediate","publicKey":{
            "challenge":"\(challenge)","rpId":"auth.example.com","userVerification":"preferred",
            "allowCredentials":[],"timeout":60000,"extensions":{}}}
            """),
            AGWKWebViewBridgePublicKeyRequest(
                rpId: "auth.example.com",
                challenge: challengeData,
                userVerification: "preferred",
                allowCredentialIDs: []
            )
        )

        // Optional fields missing; allowCredentials not empty.
        XCTAssertEqual(
            bridgePublicKeyRequest("""
            {"id":"2","type":"credentials.get","mediation":"immediate","publicKey":{
            "challenge":"\(challenge)","rpId":"auth.example.com",
            "allowCredentials":[{"type":"public-key","id":"AQID"},{"type":"public-key","id":"-_8"}]}}
            """),
            AGWKWebViewBridgePublicKeyRequest(
                rpId: "auth.example.com",
                challenge: challengeData,
                userVerification: nil,
                allowCredentialIDs: [Data([1, 2, 3]), Data([0xFB, 0xFF])]
            )
        )

        // An unknown userVerification is ignored.
        XCTAssertEqual(
            bridgePublicKeyRequest("""
            {"id":"2","type":"credentials.get","mediation":"immediate","publicKey":{
            "challenge":"\(challenge)","rpId":"auth.example.com","userVerification":"Required"}}
            """)?.userVerification,
            nil
        )

        // A password member next to publicKey is ignored.
        XCTAssertEqual(
            bridgePublicKeyRequest("""
            {"id":"2","type":"credentials.get","mediation":"immediate","password":true,"publicKey":{
            "challenge":"\(challenge)","rpId":"auth.example.com"}}
            """)?.rpId,
            "auth.example.com"
        )

        let unsupported = ["id": "2", "status": "unsupported"] as NSDictionary
        // Only a password member.
        XCTAssertEqual(
            bridgeReply(#"{"id":"2","type":"credentials.get","mediation":"immediate","password":true}"#),
            unsupported
        )
        // mediation other than immediate.
        for mediation in [#""conditional""#, #""optional""#, "null"] {
            XCTAssertEqual(
                bridgeReply("""
                {"id":"2","type":"credentials.get","mediation":\(mediation),"publicKey":{
                "challenge":"\(challenge)","rpId":"auth.example.com"}}
                """),
                unsupported
            )
        }
        // mediation missing.
        XCTAssertEqual(
            bridgeReply("""
            {"id":"2","type":"credentials.get","publicKey":{"challenge":"\(challenge)","rpId":"auth.example.com"}}
            """),
            unsupported
        )

        // Missing challenge or rpId, or a challenge that is not base64url.
        for publicKey in [
            #"{"rpId":"auth.example.com"}"#,
            "{\"challenge\":\"\(challenge)\"}",
            #"{"challenge":"not base64url!","rpId":"auth.example.com"}"#
        ] {
            XCTAssertEqual(
                bridgeReply(#"{"id":"2","type":"credentials.get","mediation":"immediate","publicKey":"# + publicKey + "}")?["status"] as? String,
                "error"
            )
        }
    }

    func testBridgePublicKeyCredential() throws {
        // Bytes whose base64 has +, / and padding.
        let credential = AGWKWebViewBridgeMessages.publicKeyCredential(
            credentialID: Data([0xFB, 0xFF]),
            clientDataJSON: Data([0xFB, 0xEF, 0xFF, 0x01]),
            authenticatorData: Data([0x3E, 0x3F]),
            signature: Data([0xFF]),
            userHandle: Data([0x01, 0x02])
        )
        let text = AGWKWebViewBridgeMessages.encodeReply(["id": "2", "status": "ok", "credential": credential])
        let reply = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(text.utf8)) as? NSDictionary)
        XCTAssertEqual(reply, [
            "id": "2",
            "status": "ok",
            "credential": [
                "id": "-_8",
                "rawId": "-_8",
                "type": "public-key",
                "authenticatorAttachment": "platform",
                "response": [
                    "clientDataJSON": "--__AQ",
                    "authenticatorData": "Pj8",
                    "signature": "_w",
                    "userHandle": "AQI"
                ],
                "clientExtensionResults": [String: Any]()
            ]
        ] as NSDictionary)
        let encoded = try XCTUnwrap(text.range(of: #""credential":"#).map { String(text[$0.upperBound...]) })
        for character in ["+", "/", "="] {
            XCTAssertFalse(encoded.contains(character), character)
        }
    }

    func testBridgePublicKeyCredentialWithoutUserHandle() throws {
        let credential = AGWKWebViewBridgeMessages.publicKeyCredential(
            credentialID: Data([0x01]),
            clientDataJSON: Data([0x02]),
            authenticatorData: Data([0x03]),
            signature: Data([0x04]),
            userHandle: nil
        )
        let response = try XCTUnwrap(credential["response"] as? [String: Any])
        XCTAssertNil(response["userHandle"])
        XCTAssertEqual(response["signature"] as? String, "BA")
    }

    func testBridgePendingRequest() throws {
        guard #available(iOS 16.0, *) else {
            throw XCTSkip("AGWKWebViewBridgePendingRequest requires iOS 16")
        }
        func makeRequest() -> (AGWKWebViewBridgePendingRequest, () -> [NSDictionary]) {
            var replies: [NSDictionary] = []
            let request = AGWKWebViewBridgePendingRequest(
                id: "2",
                replyHandler: { reply, error in
                    XCTAssertNil(error)
                    let text = reply as? String ?? ""
                    let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? NSDictionary
                    replies.append(json ?? [:])
                },
                controller: nil
            )
            return (request, { replies })
        }
        let cancelled = ["id": "2", "status": "error", "message": "cancelled"] as NSDictionary

        // finish replies once.
        var (request, replies) = makeRequest()
        request.finish(["status": "no_credential"])
        request.finish(["status": "ok"])
        XCTAssertEqual(replies(), [["id": "2", "status": "no_credential"] as NSDictionary])

        // cancel replies error once.
        (request, replies) = makeRequest()
        request.cancel()
        XCTAssertEqual(replies(), [cancelled])

        // finish after cancel replies nothing.
        (request, replies) = makeRequest()
        request.cancel()
        request.finish(["status": "no_credential"])
        XCTAssertEqual(replies(), [cancelled])

        // cancel twice replies once.
        (request, replies) = makeRequest()
        request.cancel()
        request.cancel()
        XCTAssertEqual(replies(), [cancelled])

        // cancel after finish replies nothing more.
        (request, replies) = makeRequest()
        request.finish(["status": "no_credential"])
        request.cancel()
        XCTAssertEqual(replies(), [["id": "2", "status": "no_credential"] as NSDictionary])
    }

    static var allTests = [
        ("testExample", testExample),
        ("testGetAuthenticationScopes", testGetAuthenticationScopes),
        ("testAuthenticateOptionsDefaults", testAuthenticateOptionsDefaults),
        ("testApp2AppAuthenticateRequestResource", testApp2AppAuthenticateRequestResource),
        ("testBridgeCapabilities", testBridgeCapabilities),
        ("testBridgeEnvelope", testBridgeEnvelope),
        ("testBridgeEncodeReply", testBridgeEncodeReply),
        ("testBridgeIsAllowedOrigin", testBridgeIsAllowedOrigin),
        ("testBridgeCredentialsGet", testBridgeCredentialsGet),
        ("testBridgePublicKeyCredential", testBridgePublicKeyCredential),
        ("testBridgePendingRequest", testBridgePendingRequest)
    ]
}
