import AuthenticationServices
import Foundation
import LocalAuthentication
import SafariServices
import Security
import WebKit

public typealias AuthorizeCompletionHandler = (Result<AuthorizeResult, Error>) -> Void
public typealias UserInfoCompletionHandler = (Result<UserInfo, Error>) -> Void
public typealias VoidCompletionHandler = (Result<Void, Error>) -> Void

struct AuthorizeOptions {
    let redirectURI: String
    let responseType: String?
    let state: String?
    let prompt: String?
    let loginHint: String?
    let uiLocales: [String]?
    let weChatRedirectURI: String?
    let page: String?

    var urlScheme: String {
        if let index = redirectURI.firstIndex(of: ":") {
            return String(redirectURI[..<index])
        }
        return redirectURI
    }

    public init(
        redirectURI: String,
        responseType: String,
        state: String?,
        prompt: String?,
        loginHint: String?,
        uiLocales: [String]?,
        weChatRedirectURI: String?,
        page: String?
    ) {
        self.redirectURI = redirectURI
        self.responseType = responseType
        self.state = state
        self.prompt = prompt
        self.loginHint = loginHint
        self.uiLocales = uiLocales
        self.weChatRedirectURI = weChatRedirectURI
        self.page = page
    }
}

public struct UserInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case isAnonymous = "https://authgear.com/claims/user/is_anonymous"
        case isVerified = "https://authgear.com/claims/user/is_verified"
        case iss
        case sub
    }

    public let isAnonymous: Bool
    public let isVerified: Bool
    public let iss: String
    public let sub: String

    public init(isAnonymous: Bool, isVerified: Bool, iss: String, sub: String) {
        self.isAnonymous = isAnonymous
        self.isVerified = isVerified
        self.iss = iss
        self.sub = sub
    }
}

public struct AuthorizeResult {
    public let userInfo: UserInfo
    public let state: String?
}

public enum SessionState: String {
    case unknown = "UNKNOWN"
    case noSession = "NO_SESSION"
    case authenticated = "AUTHENTICATED"
}

public enum AuthgearPage: String {
    case settings = "/settings"
    case identity = "/settings/identities"
}

public enum SessionStateChangeReason: String {
    case noToken = "NO_TOKEN"
    case foundToken = "FOUND_TOKEN"
    case authenticated = "AUTHENTICATED"
    case logout = "LOGOUT"
    case invalid = "INVALID"
}

public protocol AuthgearDelegate: AnyObject {
    func authgearSessionStateDidChange(_ container: Authgear, reason: SessionStateChangeReason)
    func sendWeChatAuthRequest(_ state: String)
}

public extension AuthgearDelegate {
    func authgearSessionStateDidChange(_ container: Authgear, reason: SessionStateChangeReason) {}
    func sendWeChatAuthRequest(_ state: String) {}
}

public class Authgear: NSObject {
    /**
     * To prevent user from using expired access token, we have to check in advance
     * whether it had expired in `shouldRefreshAccessToken`. If we
     * use the expiry time in `TokenResponse` directly to check for expiry, it is possible
     * that the access token had passed the check but ends up being expired when it arrives at
     * the server due to slow traffic or unfair scheduler.
     *
     * To compat this, we should consider the access token expired earlier than the expiry time
     * calculated using `TokenResponse.expiresIn`. Current implementation uses
     * ExpireInPercentage of TokenResponse.expiresIn` to calculate the expiry time.
     *
     * @internal
     */
    private static let ExpireInPercentage = 0.9
    let name: String
    let apiClient: AuthAPIClient
    let storage: ContainerStorage
    // refreshTokenStorage driver will be changed by config, it could be persistent or in memory
    var refreshTokenStorage: ContainerStorage
    let clientId: String

    private let authenticationSessionProvider = AuthenticationSessionProvider()
    private var authenticationSession: AuthenticationSession?
    private var webViewViewController: UIViewController?

    public private(set) var accessToken: String?
    private var refreshToken: String?
    private var expireAt: Date?

    private let jwkStore = JWKStore()
    private let workerQueue: DispatchQueue

    private var currentWeChatRedirectURI: String?

    public private(set) var sessionState: SessionState = .unknown

    public weak var delegate: AuthgearDelegate?

    static let globalMemoryStore: ContainerStorage = DefaultContainerStorage(storageDriver: MemoryStorageDriver())

    public init(clientId: String, endpoint: String, name: String? = nil) {
        self.clientId = clientId
        self.name = name ?? "default"
        let client = DefaultAuthAPIClient(endpoint: URL(string: endpoint)!)
        self.apiClient = client

        storage = DefaultContainerStorage(storageDriver: KeychainStorageDriver())
        refreshTokenStorage = storage
        workerQueue = DispatchQueue(label: "authgear:\(self.name)", qos: .utility)

        super.init()
        client.delegate = self
    }

    public func configure(
        transientSession: Bool = false,
        handler: VoidCompletionHandler? = nil
    ) {
        if transientSession {
            self.refreshTokenStorage = Authgear.globalMemoryStore
        } else {
            self.refreshTokenStorage = self.storage
        }
        workerQueue.async {
            let refreshToken = Result { try self.refreshTokenStorage.getRefreshToken(namespace: self.name) }
            switch refreshToken {
            case let .success(token):
                DispatchQueue.main.async {
                    self.refreshToken = token
                    self.setSessionState(token == nil ? .noSession : .authenticated, reason: .foundToken)
                    handler?(.success(()))
                }

            case let .failure(error):
                DispatchQueue.main.async {
                    handler?(.failure(error))
                }
            }
        }
    }

    private func setSessionState(_ newState: SessionState, reason: SessionStateChangeReason) {
        sessionState = newState
        delegate?.authgearSessionStateDidChange(self, reason: reason)
    }

    private func authorizeEndpoint(_ options: AuthorizeOptions, verifier: CodeVerifier?) throws -> URL {
        let configuration = try apiClient.syncFetchOIDCConfiguration()
        var queryItems = [URLQueryItem(name: "response_type", value: options.responseType)]

        if let verifier = verifier {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "code_challenge", value: verifier.computeCodeChallenge())
            ])
        }

        queryItems.append(URLQueryItem(
            name: "scope",
            value: "openid offline_access https://authgear.com/scopes/full-access"
        ))

        queryItems.append(URLQueryItem(name: "client_id", value: clientId))
        queryItems.append(URLQueryItem(name: "redirect_uri", value: options.redirectURI))

        if let state = options.state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }

        if let prompt = options.prompt {
            queryItems.append(URLQueryItem(name: "prompt", value: prompt))
        }

        if let loginHint = options.loginHint {
            queryItems.append(URLQueryItem(name: "login_hint", value: loginHint))
        }

        if let uiLocales = options.uiLocales {
            queryItems.append(URLQueryItem(
                name: "ui_locales",
                value: uiLocales.joined(separator: " ")
            ))
        }

        if let weChatRedirectURI = options.weChatRedirectURI {
            queryItems.append(URLQueryItem(
                name: "x_wechat_redirect_uri",
                value: weChatRedirectURI
            ))
        }

        queryItems.append(URLQueryItem(name: "x_platform", value: "ios"))

        if let page = options.page {
            queryItems.append(URLQueryItem(name: "x_page", value: page))
        }

        var urlComponents = URLComponents(
            url: configuration.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        )!

        urlComponents.queryItems = queryItems

        return urlComponents.url!
    }

    private func authorizeWithSession(
        _ options: AuthorizeOptions,
        handler: @escaping AuthorizeCompletionHandler
    ) {
        let verifier = CodeVerifier()
        let url = Result { try authorizeEndpoint(options, verifier: verifier) }

        DispatchQueue.main.async {
            switch url {
            case let .success(url):
                self.registerCurrentWeChatRedirectURI(uri: options.weChatRedirectURI)
                self.authenticationSession = self.authenticationSessionProvider.makeAuthenticationSession(
                    url: url,
                    callbackURLSchema: options.urlScheme,
                    completionHandler: { [weak self] result in
                        self?.unregisterCurrentWeChatRedirectURI()
                        switch result {
                        case let .success(url):
                            self?.workerQueue.async {
                                self?.finishAuthorization(url: url, verifier: verifier, handler: handler)
                            }
                        case let .failure(error):
                            switch error {
                            case .canceledLogin:
                                return handler(.failure(AuthgearError.canceledLogin))
                            case let .sessionError(error):
                                return handler(.failure(AuthgearError.unexpectedError(error)))
                            }
                        }
                    }
                )
                self.authenticationSession?.start()
            case let .failure(error):
                handler(.failure(error))
            }
        }
    }

    private func authorize(
        _ options: AuthorizeOptions,
        handler: @escaping AuthorizeCompletionHandler
    ) {
        workerQueue.async {
            self.authorizeWithSession(options, handler: handler)
        }
    }

    private func finishAuthorization(
        url: URL,
        verifier: CodeVerifier,
        handler: @escaping AuthorizeCompletionHandler
    ) {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let params = urlComponents.queryParams
        let state = params["state"]

        if let errorParams = params["error"] {
            return handler(
                .failure(AuthgearError.oauthError(
                    error: errorParams,
                    description: params["error_description"]
                ))
            )
        }

        guard let code = params["code"] else {
            return handler(
                .failure(AuthgearError.oauthError(
                    error: "invalid_request",
                    description: "Missing parameter: code"
                ))
            )
        }
        let redirectURI = { () -> String in
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            urlComponents.fragment = nil
            urlComponents.query = nil

            return urlComponents.url!.absoluteString
        }()

        do {
            let oidcTokenResponse = try apiClient.syncRequestOIDCToken(
                grantType: GrantType.authorizationCode,
                clientId: clientId,
                redirectURI: redirectURI,
                code: code,
                codeVerifier: verifier.value,
                refreshToken: nil,
                jwt: nil
            )

            let userInfo = try apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken)

            let result = persistSession(oidcTokenResponse, reason: .authenticated)
                .flatMap {
                    Result { () -> Void in
                        if #available(iOS 11.3, *) {
                            try self.disableBiometric()
                        }
                    }
                }
                .map { AuthorizeResult(userInfo: userInfo, state: state) }
            return handler(result)

        } catch {
            return handler(.failure(error))
        }
    }

    private func persistSession(_ oidcTokenResponse: OIDCTokenResponse, reason: SessionStateChangeReason) -> Result<Void, Error> {
        if let refreshToken = oidcTokenResponse.refreshToken {
            let result = Result { try self.refreshTokenStorage.setRefreshToken(namespace: self.name, token: refreshToken) }
            guard case .success = result else {
                return result
            }
        }

        DispatchQueue.main.async {
            self.accessToken = oidcTokenResponse.accessToken
            self.refreshToken = oidcTokenResponse.refreshToken
            self.expireAt = Date(timeIntervalSinceNow: TimeInterval(Double(oidcTokenResponse.expiresIn) * Authgear.ExpireInPercentage))
            self.setSessionState(.authenticated, reason: reason)
        }
        return .success(())
    }

    private func cleanupSession(force: Bool, reason: SessionStateChangeReason) -> Result<Void, Error> {
        if case let .failure(error) = Result(catching: { try refreshTokenStorage.delRefreshToken(namespace: name) }) {
            if !force {
                return .failure(error)
            }
        }
        if case let .failure(error) = Result(catching: { try storage.delAnonymousKeyId(namespace: name) }) {
            if !force {
                return .failure(error)
            }
        }

        DispatchQueue.main.async {
            self.accessToken = nil
            self.refreshToken = nil
            self.expireAt = nil
            self.setSessionState(.noSession, reason: reason)
        }
        return .success(())
    }

    private func withMainQueueHandler<ResultType, ErrorType: Error>(
        _ handler: @escaping (Result<ResultType, ErrorType>) -> Void
    ) -> ((Result<ResultType, ErrorType>) -> Void) {
        return { result in
            DispatchQueue.main.async {
                handler(result)
            }
        }
    }

    private func registerCurrentWeChatRedirectURI(uri: String?) {
        currentWeChatRedirectURI = uri
    }

    private func unregisterCurrentWeChatRedirectURI() {
        currentWeChatRedirectURI = nil
    }

    private func handleWeChatRedirectURI(_ url: URL) -> Bool {
        if currentWeChatRedirectURI == nil {
            return false
        }

        guard var uc = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        // get state
        let params = uc.queryParams
        let state = params["state"]
        if (state ?? "").isEmpty {
            return false
        }

        // construct and compare url without query
        uc.query = nil
        uc.fragment = nil
        guard let urlWithoutQuery = uc.string else {
            return false
        }

        if urlWithoutQuery == currentWeChatRedirectURI {
            delegate?.sendWeChatAuthRequest(state!)
            return true
        }

        return false
    }

    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL {
            _ = handleWeChatRedirectURI(url)
        }
        return true
    }

    @available(iOS 13.0, *)
    public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return
        }
        _ = handleWeChatRedirectURI(url)
    }

    public func authorize(
        redirectURI: String,
        state: String? = nil,
        prompt: String? = nil,
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        weChatRedirectURI: String? = nil,
        page: String? = nil,
        handler: @escaping AuthorizeCompletionHandler
    ) {
        authorize(
            AuthorizeOptions(
                redirectURI: redirectURI,
                responseType: "code",
                state: state,
                prompt: prompt,
                loginHint: loginHint,
                uiLocales: uiLocales,
                weChatRedirectURI: weChatRedirectURI,
                page: page
            ),
            handler: withMainQueueHandler(handler)
        )
    }

    public func authenticateAnonymously(
        handler: @escaping AuthorizeCompletionHandler
    ) {
        let handler = withMainQueueHandler(handler)
        workerQueue.async {
            do {
                let token = try self.apiClient.syncRequestOAuthChallenge(purpose: "anonymous_request").token
                let keyId = try self.storage.getAnonymousKeyId(namespace: self.name) ?? UUID().uuidString
                let tag = "com.authgear.keys.anonymous.\(keyId)"

                let header: JWTHeader
                if let key = try self.jwkStore.loadKey(keyId: keyId, tag: tag) {
                    header = JWTHeader(typ: .anonymous, jwk: key, new: false)
                } else {
                    let key = try self.jwkStore.generateKey(keyId: keyId, tag: tag)
                    header = JWTHeader(typ: .anonymous, jwk: key, new: true)
                }

                let payload = JWTPayload(challenge: token, action: AnonymousPayloadAction.auth.rawValue)

                let jwt = JWT(header: header, payload: payload)

                let privateKey = try self.jwkStore.loadPrivateKey(tag: tag)!

                let signedJWT = try jwt.sign(with: JWTSigner(privateKey: privateKey))

                let oidcTokenResponse = try self.apiClient.syncRequestOIDCToken(
                    grantType: .anonymous,
                    clientId: self.clientId,
                    redirectURI: nil,
                    code: nil,
                    codeVerifier: nil,
                    refreshToken: nil,
                    jwt: signedJWT
                )

                let userInfo = try self.apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken)

                let result = self.persistSession(oidcTokenResponse, reason: .authenticated)
                    .flatMap {
                        Result { () -> Void in
                            try self.storage.setAnonymousKeyId(namespace: self.name, kid: keyId)
                            if #available(iOS 11.3, *) {
                                try self.disableBiometric()
                            }
                        }
                    }
                    .map { AuthorizeResult(userInfo: userInfo, state: nil) }
                handler(result)

            } catch {
                handler(.failure(error))
            }
        }
    }

    public func promoteAnonymousUser(
        redirectURI: String,
        state: String? = nil,
        uiLocales: [String]? = nil,
        weChatRedirectURI: String? = nil,
        handler: @escaping AuthorizeCompletionHandler
    ) {
        let handler = withMainQueueHandler(handler)
        workerQueue.async {
            do {
                guard let keyId = try self.storage.getAnonymousKeyId(namespace: self.name) else {
                    return handler(.failure(AuthgearError.anonymousUserNotFound))
                }

                let tag = "com.authgear.keys.anonymous.\(keyId)"
                let token = try self.apiClient.syncRequestOAuthChallenge(purpose: "anonymous_request").token

                let header: JWTHeader
                if let key = try self.jwkStore.loadKey(keyId: keyId, tag: tag) {
                    header = JWTHeader(typ: .anonymous, jwk: key, new: false)
                } else {
                    let key = try self.jwkStore.generateKey(keyId: keyId, tag: tag)
                    header = JWTHeader(typ: .anonymous, jwk: key, new: true)
                }

                let payload = JWTPayload(challenge: token, action: AnonymousPayloadAction.promote.rawValue)

                let jwt = JWT(header: header, payload: payload)

                let privateKey = try self.jwkStore.loadPrivateKey(tag: tag)!

                let signedJWT = try jwt.sign(with: JWTSigner(privateKey: privateKey))

                let loginHint = "https://authgear.com/login_hint?type=anonymous&jwt=\(signedJWT.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

                self.authorize(
                    AuthorizeOptions(
                        redirectURI: redirectURI,
                        responseType: "code",
                        state: state,
                        prompt: "login",
                        loginHint: loginHint,
                        uiLocales: uiLocales,
                        weChatRedirectURI: weChatRedirectURI,
                        page: nil
                    )
                ) { [weak self] result in
                    guard let this = self else { return }

                    switch result {
                    case let .success(response):
                        this.workerQueue.async {
                            let result = Result { try this.storage.delAnonymousKeyId(namespace: this.name) }
                            handler(result.map { response })
                        }
                    case let .failure(error):
                        handler(.failure(error))
                    }
                }
            } catch {
                handler(.failure(error))
            }
        }
    }

    public func logout(
        force: Bool = false,
        redirectURI: String? = nil,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        let handler = withMainQueueHandler(handler)
        workerQueue.async {
            do {
                let token = try self.refreshTokenStorage.getRefreshToken(
                    namespace: self.name
                )
                try self.apiClient.syncRequestOIDCRevocation(
                    refreshToken: token ?? ""
                )
                return handler(self.cleanupSession(force: force, reason: .logout))

            } catch {
                if force {
                    return handler(self.cleanupSession(force: true, reason: .logout))
                }
                return handler(.failure(error))
            }
        }
    }

    public func openUrl(
        path: String,
        wechatRedirectURI: String? = nil,
        handler: VoidCompletionHandler? = nil
    ) {
        let handler = handler.map { h in withMainQueueHandler(h) }
        let url = apiClient.endpoint.appendingPathComponent(path)

        workerQueue.async {
            do {
                guard let refreshToken = try self.refreshTokenStorage.getRefreshToken(namespace: self.name) else {
                    handler?(.failure(AuthgearError.unauthenticatedUser))
                    return
                }

                let token = try self.apiClient.syncRequestAppSessionToken(refreshToken: refreshToken).appSessionToken

                let loginHint = "https://authgear.com/login_hint?type=app_session_token&app_session_token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

                let endpoint = try self.authorizeEndpoint(
                    AuthorizeOptions(
                        redirectURI: url.absoluteString,
                        responseType: "none",
                        state: nil,
                        prompt: "none",
                        loginHint: loginHint,
                        uiLocales: nil,
                        weChatRedirectURI: wechatRedirectURI,
                        page: nil
                    ),
                    verifier: nil
                )

                DispatchQueue.main.async {
                    // For opening setting page, sdk will not know when user end
                    // the setting page.
                    // So we cannot unregister the wechat uri in this case
                    // It is fine to not unresgister it, as everytime we open a
                    // new authorize section (authorize or setting page)
                    // registerCurrentWeChatRedirectURI will be called and overwrite
                    // previous registered wechatRedirectURI
                    self.registerCurrentWeChatRedirectURI(uri: wechatRedirectURI)

                    let vc = UIViewController()
                    let wv = WKWebView(frame: vc.view.bounds)
                    wv.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    wv.navigationDelegate = self
                    wv.load(URLRequest(url: endpoint))
                    vc.view.addSubview(wv)
                    vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.dismissWebView))
                    self.webViewViewController = vc

                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .pageSheet

                    let window = UIApplication.shared.windows.filter { $0.isKeyWindow }.first
                    window?.rootViewController?.present(nav, animated: true) {
                        handler?(.success(()))
                    }
                }
            } catch {
                handler?(.failure(error))
            }
        }
    }

    @objc func dismissWebView() {
        webViewViewController?.presentingViewController?.dismiss(animated: true)
        webViewViewController = nil
    }

    public func open(
        page: AuthgearPage,
        wechatRedirectURI: String? = nil
    ) {
        openUrl(path: page.rawValue, wechatRedirectURI: wechatRedirectURI)
    }

    private func shouldRefreshAccessToken() -> Bool {
        if refreshToken == nil {
            return false
        }

        guard accessToken != nil,
              let expireAt = self.expireAt,
              expireAt.timeIntervalSinceNow.sign == .minus else {
            return true
        }

        return false
    }

    private func refreshAccessToken(handler: VoidCompletionHandler? = nil) {
        let handler = handler.map { h in withMainQueueHandler(h) }
        workerQueue.async {
            do {
                guard let refreshToken = try self.refreshTokenStorage.getRefreshToken(namespace: self.name) else {
                    let result = self.cleanupSession(force: true, reason: .noToken)
                    handler?(result)
                    return
                }

                let oidcTokenResponse = try self.apiClient.syncRequestOIDCToken(
                    grantType: GrantType.refreshToken,
                    clientId: self.clientId,
                    redirectURI: nil,
                    code: nil,
                    codeVerifier: nil,
                    refreshToken: refreshToken,
                    jwt: nil
                )

                let result = self.persistSession(oidcTokenResponse, reason: .foundToken)
                handler?(result)
            } catch {
                if let error = error as? AuthAPIClientError,
                   case let .oidcError(oidcError) = error,
                   oidcError.error == "invalid_grant" {
                    return DispatchQueue.main.async {
                        let result = self.cleanupSession(force: true, reason: .invalid)
                        handler?(result)
                    }
                }
                handler?(.failure(error))
            }
        }
    }

    public func refreshAccessTokenIfNeeded(
        handler: @escaping VoidCompletionHandler
    ) {
        if shouldRefreshAccessToken() {
            refreshAccessToken { result in
                handler(result)
            }
        } else {
            handler(.success(()))
        }
    }

    public func clearRefreshToken(
        handler: @escaping VoidCompletionHandler
    ) {
        let result = self.cleanupSession(force: true, reason: .clear)
        handler(result)
    }

    public func fetchUserInfo(handler: @escaping UserInfoCompletionHandler) {
        let handler = withMainQueueHandler(handler)
        let fetchUserInfo = { (accessToken: String) in
            self.workerQueue.async {
                let result = Result { try self.apiClient.syncRequestOIDCUserInfo(accessToken: accessToken) }
                handler(result)
            }
        }

        refreshAccessTokenIfNeeded { _ in
            fetchUserInfo(self.accessToken ?? "")
        }
    }

    public func weChatAuthCallback(code: String, state: String, handler: VoidCompletionHandler? = nil) {
        let handler = handler.map { h in withMainQueueHandler(h) }
        workerQueue.async {
            do {
                try self.apiClient.syncRequestWeChatAuthCallback(
                    code: code,
                    state: state
                )
                handler?(.success(()))
            } catch {
                handler?(.failure(error))
            }
        }
    }

    @available(iOS 11.3, *)
    public func checkBiometricSupported() throws {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if let error = error {
            throw error
        }
    }

    @available(iOS 11.3, *)
    public func isBiometricEnabled() throws -> Bool {
        if let _ = try storage.getBiometricKeyId(namespace: name) {
            return true
        } else {
            return false
        }
    }

    @available(iOS 11.3, *)
    public func disableBiometric() throws {
        if let kid = try storage.getBiometricKeyId(namespace: name) {
            let tag = "com.authgear.keys.biometric.\(kid)"
            try removePrivateKey(tag: tag)
            try storage.delBiometricKeyId(namespace: name)
        }
    }

    @available(iOS 11.3, *)
    public func enableBiometric(localizedReason: String, constraint: BiometricAccessConstraint, handler: @escaping VoidCompletionHandler) {
        let handler = withMainQueueHandler(handler)

        let context = LAContext()
        // First we perform a biometric authentication first.
        // But this actually is just a test to ensure biometric authentication works.
        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: localizedReason
        ) { _, error in
            if let error = error {
                handler(.failure(error))
                return
            }

            let biometricSetup = { (accessToken: String) in
                self.workerQueue.async {
                    do {
                        let challenge = try self.apiClient.syncRequestOAuthChallenge(purpose: "biometric_request").token
                        let kid = UUID().uuidString
                        let tag = "com.authgear.keys.biometric.\(kid)"
                        let privateKey = try generatePrivateKey()
                        try addPrivateKey(privateKey: privateKey, tag: tag, constraint: constraint)
                        let publicKey = SecKeyCopyPublicKey(privateKey)!
                        let jwk = try publicKeyToJWK(kid: kid, publicKey: publicKey)
                        let header = JWTHeader(typ: .biometric, jwk: jwk, new: true)
                        let payload = JWTPayload(challenge: challenge, action: BiometricPayloadAction.setup.rawValue)
                        let jwt = JWT(header: header, payload: payload)
                        let signedJWT = try jwt.sign(with: JWTSigner(privateKey: privateKey))
                        _ = try self.apiClient.syncRequestBiometricSetup(clientId: self.clientId, accessToken: accessToken, jwt: signedJWT)
                        try self.storage.setBiometricKeyId(namespace: self.name, kid: kid)
                        handler(.success(()))
                    } catch {
                        handler(.failure(error))
                    }
                }
            }

            self.refreshAccessTokenIfNeeded { _ in
                biometricSetup(self.accessToken ?? "")
            }
        }
    }

    @available(iOS 11.3, *)
    public func authenticateBiometric(handler: @escaping AuthorizeCompletionHandler) {
        let handler = withMainQueueHandler(handler)
        workerQueue.async {
            do {
                guard let kid = try self.storage.getBiometricKeyId(namespace: self.name) else {
                    throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound), userInfo: nil)
                }
                let challenge = try self.apiClient.syncRequestOAuthChallenge(purpose: "biometric_request").token
                let tag = "com.authgear.keys.biometric.\(kid)"
                guard let privateKey = try getPrivateKey(tag: tag) else {
                    // If the constraint was biometryCurrentSet,
                    // then the private key may be deleted by the system
                    // when biometric has been changed by the device owner.
                    // In this case, perform cleanup.
                    try self.disableBiometric()
                    throw NSError(domain: NSOSStatusErrorDomain, code: Int(errSecItemNotFound), userInfo: nil)
                }
                let publicKey = SecKeyCopyPublicKey(privateKey)!
                let jwk = try publicKeyToJWK(kid: kid, publicKey: publicKey)
                let header = JWTHeader(typ: .biometric, jwk: jwk, new: false)
                let payload = JWTPayload(challenge: challenge, action: BiometricPayloadAction.authenticate.rawValue)
                let jwt = JWT(header: header, payload: payload)
                let signedJWT = try jwt.sign(with: JWTSigner(privateKey: privateKey))
                let oidcTokenResponse = try self.apiClient.syncRequestOIDCToken(
                    grantType: .biometric,
                    clientId: self.clientId,
                    redirectURI: nil,
                    code: nil,
                    codeVerifier: nil,
                    refreshToken: nil,
                    jwt: signedJWT
                )

                let userInfo = try self.apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken)
                let result = self.persistSession(oidcTokenResponse, reason: .authenticated)
                    .map { AuthorizeResult(userInfo: userInfo, state: nil) }
                return handler(result)
            } catch {
                // In case the biometric was removed remotely.
                if case let AuthAPIClientError.oidcError(error) = error {
                    if error.error == "invalid_grant" && error.errorDescription == "InvalidCredentials" {
                        try? self.disableBiometric()
                    }
                }
                handler(.failure(error))
            }
        }
    }
}

extension Authgear: AuthAPIClientDelegate {
    func getAccessToken() -> String? {
        accessToken
    }
}

extension Authgear: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let isWeChatRedirectURI = handleWeChatRedirectURI(url)
            if isWeChatRedirectURI {
                decisionHandler(.cancel)
                return
            }
        }

        decisionHandler(.allow)
    }
}
