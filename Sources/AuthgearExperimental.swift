import Foundation

public struct AuthgearExperimental {
    let authgear: Authgear

    public func generateURL(redirectURI: String, handler: URLCompletionHandler?) {
        self.authgear.generateURL(redirectURI: redirectURI, handler: handler)
    }
}

public extension Authgear {
    var experimental: AuthgearExperimental {
        AuthgearExperimental(authgear: self)
    }
}
