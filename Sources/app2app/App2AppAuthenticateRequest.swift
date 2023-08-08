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
}
