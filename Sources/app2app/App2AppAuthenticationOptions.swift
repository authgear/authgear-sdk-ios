import Foundation

public struct App2AppAuthenticateOptions {
    let authorizationEndpoint: String
    let redirectUri: String
    let state: String?

    public init(
        authorizationEndpoint: String,
        redirectUri: String,
        state: String? = nil
    ) {
        self.authorizationEndpoint = authorizationEndpoint
        self.redirectUri = redirectUri
        self.state = state
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
            state: state
        )
    }
}
