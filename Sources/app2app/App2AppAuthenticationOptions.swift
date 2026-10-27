import Foundation

public struct App2AppAuthenticateOptions {
    let authorizationEndpoint: String
    let redirectUri: String
    let state: String?
    /// Resource indicator (RFC 8707) for the new session of this app. Defaults to the `resource` given to `Authgear.configure`.
    public let resource: String?

    public init(
        authorizationEndpoint: String,
        redirectUri: String,
        state: String? = nil,
        resource: String? = nil
    ) {
        self.authorizationEndpoint = authorizationEndpoint
        self.redirectUri = redirectUri
        self.state = state
        self.resource = resource
    }

    func withResource(_ resource: String?) -> App2AppAuthenticateOptions {
        App2AppAuthenticateOptions(
            authorizationEndpoint: authorizationEndpoint,
            redirectUri: redirectUri,
            state: state,
            resource: resource
        )
    }

    func toRequest(
        clientID: String,
        codeVerifier: CodeVerifier
    ) -> App2AppAuthenticateRequest {
        App2AppAuthenticateRequest(
            authorizationEndpoint: authorizationEndpoint,
            redirectUri: URL(string: redirectUri)!,
            clientID: clientID,
            codeChallenge: codeVerifier.codeChallenge,
            state: state,
            resource: resource
        )
    }
}
