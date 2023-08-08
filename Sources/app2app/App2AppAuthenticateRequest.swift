import Foundation

public struct App2AppAuthenticateRequest {
    public let authorizationEndpoint: String
    public let redirectUri: String
    public let clientID: String
    public let codeChallenge: String
    
    func toURL() throws -> URL {
        let urlcomponents = URLComponents(string: authorizationEndpoint)
        guard var urlcomponents = urlcomponents else {
            throw AuthgearError.runtimeError("invalid authorizationEndpoint")
        }
        let query: [String:String] = [
            "client_id": clientID,
            "redirect_uri": redirectUri,
            "code_challenge_method": Authgear.CodeChallengeMethod,
            "code_challenge": codeChallenge
        ]
        urlcomponents.percentEncodedQuery = query.encodeAsQuery()
        return urlcomponents.url!.absoluteURL
    }
    
    static func parse(url: URL) -> App2AppAuthenticateRequest? {
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
        guard let redirectUri = queryParams["redirect_uri"] else {
            return nil
        }
        guard let clientID = queryParams["client_id"] else {
            return nil
        }
        guard let codeChallenge = queryParams["code_challenge"] else {
            return nil
        }
        return App2AppAuthenticateRequest(
            authorizationEndpoint: authorizationEndpointURL.absoluteString,
            redirectUri: redirectUri,
            clientID: clientID,
            codeChallenge: codeChallenge)
    }
}
