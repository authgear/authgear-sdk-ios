import AuthenticationServices
import Foundation
import SafariServices

public typealias AuthorizeCompletionHandler = (Result<AuthorizeResponse, Error>) -> Void
public typealias VoidCompletionHandler = (Result<Void, Error>
) -> Void

struct AuthorizeOptions {
    let redirectURI: String
    let state: String?
    let prompt: String?
    let loginHint: String?
    let uiLocales: [String]?

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
        uiLocales: [String]?
    ) {
        self.redirectURI = redirectURI
        self.state = state
        self.prompt = prompt
        self.loginHint = loginHint
        self.uiLocales = uiLocales
    }
}

public struct UserInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case isAnonymous = "https://authgear.com/claims/user/is_anonymous"
        case isVerified = "https://authgear.com/claims/user/is_verified"
        case iss
        case sub
    }

    let isAnonymous: Bool
    let isVerified: Bool
    let iss: String
    let sub: String
}

public struct AuthorizeResponse {
    public let userInfo: UserInfo
    public let state: String?
}

public protocol AuthgearDelegate: AnyObject {
    func onRefreshTokenExpired()
}

public class Authgear: NSObject {
    let name: String
    let apiClient: AuthAPIClient
    let storage: ContainerStorage
    let clientId: String

    private let authenticationSessionProvider = AuthenticationSessionProvider()
    private var authenticationSession: AuthenticationSession?

    private var accessToken: String?
    private var refreshToken: String?
    private var expireAt: Date?

    private let jwkStore = JWKStore()
    private let workerQueue: DispatchQueue

    public weak var delegate: AuthgearDelegate?

    public init(clientId: String, endpoint: String, name: String? = nil) {
        self.clientId = clientId
        self.name = name ?? "default"
        apiClient = DefaultAuthAPIClient()
        apiClient.endpoint = URL(string: endpoint)

        storage = DefaultContainerStorage(storageDriver: KeychainStorageDriver())
        workerQueue = DispatchQueue(label: "authgear:\(self.name)", qos: .utility)
    }

    public func configure(
        skipRefreshAccessToken: Bool = false,
        handler: VoidCompletionHandler? = nil
    ) {
        refreshToken = try? storage.getRefreshToken(namespace: name)

        if shouldRefreshAccessToken() {
            if !skipRefreshAccessToken {
                refreshAccessToken(handler: handler)
            }
        }
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

    private func authorize(
        _ options: AuthorizeOptions,
        handler: @escaping AuthorizeCompletionHandler
    ) {
        let verifier = CodeVerifier()
        do {
            let url = try authorizeEndpoint(options, verifier: verifier)
            DispatchQueue.main.async {
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
                                return handler(
                                    .failure(AuthgearError.canceledLogin)
                                )
                            case let .sessionError(error):
                                return handler(
                                    .failure(AuthgearError.unexpectedError(error))
                                )
                            }
                        }
                    }
                )
                self.authenticationSession?.start()
            }
        } catch {
            handler(.failure(error))
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
                )
                )
            )
        }
        let redirectURI = { () -> String in
            var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            urlComponents.fragment = nil
            urlComponents.query = nil

            return urlComponents.url!.absoluteString
        }()

        do {
            let tokenResponse = try apiClient.syncRequestOIDCToken(
                grantType: GrantType.authorizationCode,
                clientId: clientId,
                redirectURI: redirectURI,
                code: code,
                codeVerifier: verifier.value,
                refreshToken: nil,
                jwt: nil
            )

            let userInfo = try apiClient.syncRequestOIDCUserInfo(accessToken: tokenResponse.accessToken)
            try persistTokenResponse(tokenResponse)

            handler(.success(AuthorizeResponse(userInfo: userInfo, state: state)))
        } catch {
            handler(.failure(error))
        }
    }

    private func persistTokenResponse(
        _ tokenResponse: TokenResponse
    ) throws {
        accessToken = tokenResponse.accessToken
        refreshToken = tokenResponse.refreshToken
        expireAt = Date(timeIntervalSinceNow: TimeInterval(tokenResponse.expiresIn))

        if let refreshToekn = tokenResponse.refreshToken {
            try storage.setRefreshToken(namespace: name, token: refreshToekn)
        }
    }

    private func cleanupSession() throws {
        try storage.delRefreshToken(namespace: name)
        try storage.delAnonymousKeyId(namespace: name)
        accessToken = nil
        refreshToken = nil
        expireAt = nil
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

    public func authorize(
        redirectURI: String,
        state: String? = nil,
        prompt: String? = "login",
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        handler: @escaping AuthorizeCompletionHandler
    ) {
        workerQueue.async {
            self.authorize(
                AuthorizeOptions(
                    redirectURI: redirectURI,
                    state: state,
                    prompt: prompt,
                    loginHint: loginHint,
                    uiLocales: uiLocales
                ),
                handler: self.withMainQueueHandler(handler)
            )
        }
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

                let tokenResponse = try self.apiClient.syncRequestOIDCToken(
                    grantType: .anonymous,
                    clientId: self.clientId,
                    redirectURI: nil,
                    code: nil,
                    codeVerifier: nil,
                    refreshToken: nil,
                    jwt: signedJWT
                )

                let userInfo = try self.apiClient.syncRequestOIDCUserInfo(accessToken: tokenResponse.accessToken)

                try self.persistTokenResponse(tokenResponse)
                try self.storage.setAnonymousKeyId(namespace: self.name, kid: keyId)

                handler(.success(AuthorizeResponse(userInfo: userInfo, state: nil)))
            } catch {
                handler(.failure(error))
            }
        }
    }

    public func promoteAnonymousUser(
        redirectURI: String,
        state: String? = nil,
        uiLocales: [String]? = nil,
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
                    redirectURI: redirectURI,
                    state: state,
                    prompt: "login",
                    loginHint: loginHint,
                    uiLocales: uiLocales
                ) { [weak self] result in
                    guard let this = self else { return }

                    switch result {
                    case let .success(response):
                        try? this.storage.delAnonymousKeyId(namespace: this.name)
                        handler(.success(response
                        ))
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
                try self.cleanupSession()
                handler(.success(()))
            } catch {
                handler(.failure(error))
            }
        }
    }
}

extension Authgear: AuthAPIClientDelegate {
    func getAccessToken() -> String? {
        accessToken
    }

    func shouldRefreshAccessToken() -> Bool {
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

    func refreshAccessToken(handler: VoidCompletionHandler?) {
        workerQueue.async {
            do {
                guard let refreshToken = try self.storage.getRefreshToken(namespace: self.name) else {
                    try self.cleanupSession()
                    handler?(.success(()))
                    return
                }

                let tokenResponse = try self.apiClient.syncRequestOIDCToken(
                    grantType: GrantType.refreshToken,
                    clientId: self.clientId,
                    redirectURI: nil,
                    code: nil,
                    codeVerifier: nil,
                    refreshToken: refreshToken,
                    jwt: nil
                )

                try self.persistTokenResponse(tokenResponse)
            } catch {
                if let error = error as? AuthAPIClientError,
                    case let .oidcError(oidcError) = error,
                    oidcError.error == "invalid_grant" {
                    self.delegate?.onRefreshTokenExpired()
                    try? self.cleanupSession()
                    handler?(.success(()))
                    return
                }
                handler?(.failure(error))
            }
        }
    }
}
