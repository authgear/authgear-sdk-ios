import Foundation

public struct App2AppAuthenticateRequest {
    public let authorizationEndpoint: String
    public let redirectUri: URL
    public let clientID: String
    public let codeChallenge: String

    func toURL() throws -> URL {
        let urlcomponents = URLComponents(string: authorizationEndpoint)
        guard var urlcomponents = urlcomponents else {
            throw AuthgearError.runtimeError("invalid authorizationEndpoint")
        }
        let query: [String: String] = [
            "client_id": clientID,
            "redirect_uri": redirectUri.absoluteString,
            "code_challenge_method": Authgear.CodeChallengeMethod,
            "code_challenge": codeChallenge
        ]
        urlcomponents.percentEncodedQuery = query.encodeAsQuery()
        return urlcomponents.url!.absoluteURL
    }

    init?(url: URL) {
        let urlcomponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let urlcomponents = urlcomponents else {
            return nil
        }
        let queryParams = urlcomponents.queryParams
        let authorizationEndpointURLComponents = URLComponents(string: url.absoluteString)
        guard var authorizationEndpointURLComponents = authorizationEndpointURLComponents else {
            return nil
        }
        authorizationEndpointURLComponents.percentEncodedQuery = nil
        guard let authorizationEndpointURL = authorizationEndpointURLComponents.url else {
            return nil
        }
        guard let redirectUriStr = queryParams["redirect_uri"],
              let redirectUri = URL(string: redirectUriStr) else {
            return nil
        }
        guard let clientID = queryParams["client_id"] else {
            return nil
        }
        guard let codeChallenge = queryParams["code_challenge"] else {
            return nil
        }
        self.authorizationEndpoint = authorizationEndpointURL.absoluteString
        self.redirectUri = redirectUri
        self.clientID = clientID
        self.codeChallenge = codeChallenge
    }

    init(
        authorizationEndpoint: String,
        redirectUri: URL,
        clientID: String,
        codeChallenge: String
    ) {
        self.authorizationEndpoint = authorizationEndpoint
        self.redirectUri = redirectUri
        self.clientID = clientID
        self.codeChallenge = codeChallenge
    }
}
