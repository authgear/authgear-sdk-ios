import AuthenticationServices
import Foundation
import SafariServices

public typealias AuthorizeCompletionHandler = (Result<AuthorizeResult, Error>) -> Void
public typealias AuthorizeRedirectionHandler = (URL) -> Void
public typealias UserInfoCompletionHandler = (Result<UserInfo, Error>) -> Void
public typealias VoidCompletionHandler = (Result<Void, Error>) -> Void

struct AuthorizeOptions {
    let redirectURI: String
    let state: String?
    let prompt: String?
    let loginHint: String?
    let uiLocales: [String]?
    let prefersSFSafariViewController: Bool

    var urlScheme: String {
        if let index = redirectURI.firstIndex(of: ":") {
            return String(redirectURI[..<index])
        }
        return redirectURI
    }

    public init(
        redirectURI: String,
        state: String?,
        prompt: String?,
        loginHint: String?,
        uiLocales: [String]?,
        prefersSFSafariViewController: Bool
    ) {
        self.redirectURI = redirectURI
        self.state = state
        self.prompt = prompt
        self.loginHint = loginHint
        self.uiLocales = uiLocales
        self.prefersSFSafariViewController = prefersSFSafariViewController
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

public enum SessionState {
    case loggedIn
    case noSession
    case unknown
}

public enum AuthgearPage: String {
    case settings = "/settings"
    case identity = "/settings/identities"
}

public enum SessionStateChangeReason {
    case noToken
    case foundToken
    case authorized
    case logout
    case expired
}

public protocol AuthgearDelegate: AnyObject {
    func authgearRefreshTokenDidExpire(_ container: Authgear)
    func authgearSessionStateDidChange(_ container: Authgear, reason: SessionStateChangeReason)
}

public class Authgear: NSObject, SFSafariViewControllerDelegate {
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
    let clientId: String

    private let authenticationSessionProvider = AuthenticationSessionProvider()
    private var authenticationSession: AuthenticationSession?

    public private(set) var accessToken: String?
    private var refreshToken: String?
    private var expireAt: Date?

    private let jwkStore = JWKStore()
    private let workerQueue: DispatchQueue

    public private(set) var sessionState: SessionState = .unknown
    public private(set) var authorizeRedirectionHandler: AuthorizeRedirectionHandler?

    public weak var delegate: AuthgearDelegate?

    public init(clientId: String, endpoint: String, name: String? = nil) {
        self.clientId = clientId
        self.name = name ?? "default"
        apiClient = DefaultAuthAPIClient(endpoint: URL(string: endpoint)!)

        storage = DefaultContainerStorage(storageDriver: KeychainStorageDriver())
        workerQueue = DispatchQueue(label: "authgear:\(self.name)", qos: .utility)
    }

    public func configure(
        skipRefreshAccessToken: Bool = false,
        handler: VoidCompletionHandler? = nil
    ) {
        workerQueue.async {
            let refreshToken = Result { try self.storage.getRefreshToken(namespace: self.name) }
            switch refreshToken {
            case let .success(token):
                if self.shouldRefreshAccessToken() && !skipRefreshAccessToken {
                    return self.refreshAccessToken(handler: handler)
                }

                DispatchQueue.main.async {
                    self.refreshToken = token
                    self.setSessionState(token == nil ? .noSession : .loggedIn, reason: .foundToken)
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

    private func authorizeEndpoint(_ options: AuthorizeOptions, verifier: CodeVerifier) throws -> URL {
        let configuration = try apiClient.syncFetchOIDCConfiguration()
        var queryItems = [URLQueryItem]()

        queryItems.append(contentsOf: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(
                name: "scope",
                value: "openid offline_access https://authgear.com/scopes/full-access"
            ),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: verifier.computeCodeChallenge())
        ])

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

        var urlComponents = URLComponents(
            url: configuration.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        )!

        urlComponents.queryItems = queryItems

        return urlComponents.url!
    }

    private func authorizeWithoutSession(
        _ options: AuthorizeOptions,
        handler: @escaping AuthorizeCompletionHandler
    ) -> AuthorizeRedirectionHandler? {
        let verifier = CodeVerifier()
        let requestUrlResult = Result { try authorizeEndpoint(options, verifier: verifier) }
        switch requestUrlResult {
        case let .success(requestUrl):
            let vc = SFSafariViewController(url: requestUrl)
            vc.delegate = self
            vc.modalPresentationStyle = .pageSheet
            UIApplication.shared.windows.filter { $0.isKeyWindow }
                .first?.rootViewController?.present(vc, animated: true)
            let redirectHandler: (_ url: URL) -> Void = { [weak self] url in
                vc.dismiss(animated: true)
                self?.workerQueue.async {
                    self?.finishAuthorization(url: url, verifier: verifier, handler: handler)
                }
            }
            return redirectHandler
        case let .failure(error):
            handler(.failure(error))
            return nil
        }
    }

    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        controller.dismiss(animated: true)
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
                self.authenticationSession = self.authenticationSessionProvider.makeAuthenticationSession(
                    url: url,
                    callbackURLSchema: options.urlScheme,
                    completionHandler: { [weak self] result in
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
        if options.prefersSFSafariViewController {
            authorizeRedirectionHandler = authorizeWithoutSession(options, handler: handler)
        } else {
            workerQueue.async {
                self.authorizeWithSession(options, handler: handler)
            }
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

            let result = persistSession(oidcTokenResponse, reason: .authorized)
                .map { AuthorizeResult(userInfo: userInfo, state: state) }
            return handler(result)

        } catch {
            return handler(.failure(error))
        }
    }

    private func persistSession(_ oidcTokenResponse: OIDCTokenResponse, reason: SessionStateChangeReason) -> Result<Void, Error> {
        if let refreshToken = oidcTokenResponse.refreshToken {
            let result = Result { try self.storage.setRefreshToken(namespace: self.name, token: refreshToken) }
            guard case .success = result else {
                return result
            }
        }

        DispatchQueue.main.async {
            self.accessToken = oidcTokenResponse.accessToken
            self.refreshToken = oidcTokenResponse.refreshToken
            self.expireAt = Date(timeIntervalSinceNow: TimeInterval(Double(oidcTokenResponse.expiresIn) * Authgear.ExpireInPercentage))
            self.setSessionState(.loggedIn, reason: reason)
        }
        return .success(())
    }

    private func cleanupSession(force: Bool, reason: SessionStateChangeReason) -> Result<Void, Error> {
        if case let .failure(error) = Result(catching: { try storage.delRefreshToken(namespace: name) }) {
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

    public func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        authorizeRedirectionHandler?(url)
        return true
    }

    public func authorize(
        redirectURI: String,
        state: String? = nil,
        prompt: String? = "login",
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        prefersSFSafariViewController: Bool = false,
        handler: @escaping AuthorizeCompletionHandler
    ) {
        authorize(
            AuthorizeOptions(
                redirectURI: redirectURI,
                state: state,
                prompt: prompt,
                loginHint: loginHint,
                uiLocales: uiLocales,
                prefersSFSafariViewController: prefersSFSafariViewController
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

                let header: AnonymousJWTHeader
                if let key = try self.jwkStore.loadKey(keyId: keyId, tag: tag) {
                    header = AnonymousJWTHeader(jwk: key, new: false)
                } else {
                    let key = try self.jwkStore.generateKey(keyId: keyId, tag: tag)
                    header = AnonymousJWTHeader(jwk: key, new: true)
                }

                let payload = AnonymousJWYPayload(challenge: token, action: .auth)

                let jwt = AnonymousJWT(header: header, payload: payload)

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

                let result = self.persistSession(oidcTokenResponse, reason: .authorized)
                    .flatMap { Result { try self.storage.setAnonymousKeyId(namespace: self.name, kid: keyId) } }
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
        prefersSFSafariViewController: Bool = false,
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

                let header: AnonymousJWTHeader
                if let key = try self.jwkStore.loadKey(keyId: keyId, tag: tag) {
                    header = AnonymousJWTHeader(jwk: key, new: false)
                } else {
                    let key = try self.jwkStore.generateKey(keyId: keyId, tag: tag)
                    header = AnonymousJWTHeader(jwk: key, new: true)
                }

                let payload = AnonymousJWYPayload(challenge: token, action: .promote)

                let jwt = AnonymousJWT(header: header, payload: payload)

                let privateKey = try self.jwkStore.loadPrivateKey(tag: tag)!

                let signedJWT = try jwt.sign(with: JWTSigner(privateKey: privateKey))

                let loginHint = "https://authgear.com/login_hint?type=anonymous&jwt=\(signedJWT.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

                self.authorize(
                    AuthorizeOptions(
                        redirectURI: redirectURI,
                        state: state,
                        prompt: "login",
                        loginHint: loginHint,
                        uiLocales: uiLocales,
                        prefersSFSafariViewController: prefersSFSafariViewController
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
                let token = try self.storage.getRefreshToken(
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
        handler: VoidCompletionHandler? = nil
    ) {
        let handler = handler.map { h in withMainQueueHandler(h) }
        let url = apiClient.endpoint.appendingPathComponent(path)
        authenticationSession = authenticationSessionProvider.makeAuthenticationSession(
            url: url,
            callbackURLSchema: "",
            completionHandler: { result in
                switch result {
                case .success:
                    handler?(.success(()))
                case let .failure(error):
                    handler?(.failure(AuthgearError.unexpectedError(error)))
                }
            }
        )
        authenticationSession?.start()
    }

    public func open(page: AuthgearPage) {
        openUrl(path: page.rawValue)
    }

    public func shouldRefreshAccessToken() -> Bool {
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

    public func refreshAccessToken(handler: VoidCompletionHandler? = nil) {
        let handler = handler.map { h in withMainQueueHandler(h) }
        workerQueue.async {
            do {
                guard let refreshToken = try self.storage.getRefreshToken(namespace: self.name) else {
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
                        self.delegate?.authgearRefreshTokenDidExpire(self)
                        let result = self.cleanupSession(force: true, reason: .expired)
                        handler?(result)
                    }
                }
                handler?(.failure(error))
            }
        }
    }

    public func fetchUserInfo(handler: @escaping UserInfoCompletionHandler) {
        let handler = withMainQueueHandler(handler)
        let fetchUserInfo = { (accessToken: String) in
            self.workerQueue.async {
                let result = Result { try self.apiClient.syncRequestOIDCUserInfo(accessToken: accessToken) }
                handler(result)
            }
        }

        if shouldRefreshAccessToken() {
            refreshAccessToken { _ in
                fetchUserInfo(self.accessToken ?? "")
            }
        } else {
            fetchUserInfo(accessToken ?? "")
        }
    }
}

extension Authgear: AuthAPIClientDelegate {
    func getAccessToken() -> String? {
        accessToken
    }
}
