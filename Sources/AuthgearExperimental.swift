import Foundation

public struct AuthgearExperimental {
    let authgear: Authgear

    public struct AuthenticationRequest {
        public let url: URL
        public let redirectURI: String
        let verifier: CodeVerifier
    }

    public func generateURL(redirectURI: String, handler: URLCompletionHandler?) {
        self.authgear.generateURL(redirectURI: redirectURI, responseType: .none, handler: handler)
    }

    public func createAuthenticateRequest(
        redirectURI: String,
        state: String? = nil,
        xState: String? = nil,
        prompt: [PromptOption]? = nil,
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        page: AuthenticationPage? = nil,
        authenticationFlowGroup: String? = nil
    ) -> Result<AuthenticationRequest, Error> {
        let options = AuthenticateOptions(
            redirectURI: redirectURI,
            isSSOEnabled: self.authgear.isSSOEnabled,
            state: state,
            xState: xState,
            prompt: prompt,
            loginHint: loginHint,
            uiLocales: uiLocales,
            colorScheme: colorScheme,
            wechatRedirectURI: wechatRedirectURI,
            page: page,
            authenticationFlowGroup: authenticationFlowGroup
        )
        return self.authgear.createAuthenticateRequest(options).map { request in
            AuthenticationRequest.fromInternal(request)
        }
    }

    public func createReauthenticateRequest(
        redirectURI: String,
        idTokenHint: String,
        state: String? = nil,
        xState: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        authenticationFlowGroup: String? = nil
    ) -> Result<AuthenticationRequest, Error> {
        let options = ReauthenticateOptions(
            redirectURI: redirectURI,
            isSSOEnabled: self.authgear.isSSOEnabled,
            state: state,
            xState: xState,
            uiLocales: uiLocales,
            colorScheme: colorScheme,
            wechatRedirectURI: wechatRedirectURI,
            maxAge: nil,
            authenticationFlowGroup: authenticationFlowGroup
        )
        return Result<AuthenticationRequest, Error> {
            let verifier = CodeVerifier()
            let request = options.toRequest(idTokenHint: idTokenHint)
            let url = try self.authgear.buildAuthorizationURL(request: request, verifier: verifier)
            return AuthenticationRequest(url: url, redirectURI: request.redirectURI, verifier: verifier)
        }
    }

    public func finishAuthentication(
        finishURL: URL,
        request: AuthgearExperimental.AuthenticationRequest,
        handler: @escaping UserInfoCompletionHandler
    ) {
        self.authgear.finishAuthentication(
            url: finishURL,
            verifier: request.verifier,
            handler: handler
        )
    }

    public func finishReauthentication(
        finishURL: URL,
        request: AuthgearExperimental.AuthenticationRequest,
        handler: @escaping UserInfoCompletionHandler
    ) {
        self.authgear.finishReauthentication(
            url: finishURL,
            verifier: request.verifier,
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
