import Foundation

public struct AuthgearExperimental {
    let authgear: Authgear

    public struct AuthenticationRequest {
        public let url: URL
        public let redirectURI: String
        let verifier: CodeVerifier
    }

    public func generateURL(redirectURI: String, handler: URLCompletionHandler?) {
        self.authgear.generateURL(redirectURI: redirectURI, handler: handler)
    }

    public func createAuthenticateRequest(
        redirectURI: String,
        state: String? = nil,
        prompt: [PromptOption]? = nil,
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        page: AuthenticationPage? = nil
    ) -> Result<AuthenticationRequest, Error> {
        let options = AuthenticateOptions(
            redirectURI: redirectURI,
            isSSOEnabled: self.authgear.isSSOEnabled,
            state: state,
            prompt: prompt,
            loginHint: loginHint,
            uiLocales: uiLocales,
            colorScheme: colorScheme,
            wechatRedirectURI: wechatRedirectURI,
            page: page
        )
        return self.authgear.createAuthenticateRequest(options).map { request in
            AuthenticationRequest.fromInternal(request)
        }
    }

    public func finishAuthentication(
        finishURL: URL,
        request: AuthgearExperimental.AuthenticationRequest,
        handler: @escaping UserInfoCompletionHandler
    ) {
        self.authgear.finishAuthentication(
            url: finishURL,
            request: request.toInternal(),
            handler: handler
        )
    }
}

extension AuthgearExperimental.AuthenticationRequest {
    static func fromInternal(_ request: AuthenticationRequest) -> Self {
        Self(url: request.url, redirectURI: request.redirectURI, verifier: request.verifier)
    }

    func toInternal() -> AuthenticationRequest {
        AuthenticationRequest(url: self.url, redirectURI: self.redirectURI, verifier: self.verifier)
    }
}

public extension Authgear {
    var experimental: AuthgearExperimental {
        AuthgearExperimental(authgear: self)
    }
}
