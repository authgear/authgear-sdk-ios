import Foundation

public struct App2AppAuthenticateOptions {
    let authorizationEndpoint: String
    let redirectUri: String
    
    public init(
        authorizationEndpoint: String,
        redirectUri: String
    ) {
        self.authorizationEndpoint = authorizationEndpoint
        self.redirectUri = redirectUri
    }
    
    internal func toRequest(
        clientID: String,
        codeVerifier: CodeVerifier
    ) -> App2AppAuthenticateRequest {
        return App2AppAuthenticateRequest(
            authorizationEndpoint: authorizationEndpoint,
            redirectUri: redirectUri,
            clientID: clientID,
            codeChallenge: codeVerifier.codeChallenge
        )
    }
}