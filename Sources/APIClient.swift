import Foundation

enum GrantType: String {
    case authorizationCode = "authorization_code"
    case refreshToken = "refresh_token"
    case anonymous = "urn:authgear:params:oauth:grant-type:anonymous-request"
    case biometric = "urn:authgear:params:oauth:grant-type:biometric-request"
    case idToken = "urn:authgear:params:oauth:grant-type:id-token"
}

struct APIResponse<T: Decodable>: Decodable {
    let result: T

    func toResult() -> Result<T, Error> {
        .success(result)
    }
}

struct APIErrorResponse: Decodable {
    let error: ServerError
}

struct OIDCAuthenticationRequest {
    let redirectURI: String
    let responseType: String
    let scope: [String]
    let isSSOEnabled: Bool
    let state: String?
    let prompt: [PromptOption]?
    let loginHint: String?
    let uiLocales: [String]?
    let colorScheme: ColorScheme?
    let idTokenHint: String?
    let maxAge: Int?
    let wechatRedirectURI: String?
    let page: AuthenticationPage?

    var redirectURIScheme: String {
        if let index = redirectURI.firstIndex(of: ":") {
            return String(redirectURI[..<index])
        }
        return redirectURI
    }

    func toQueryItems(clientID: String, verifier: CodeVerifier?) -> [URLQueryItem] {
        var queryItems = [
            URLQueryItem(name: "response_type", value: self.responseType),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: self.redirectURI),
            URLQueryItem(
                name: "scope",
                value: scope.joined(separator: " ")
            ),
            URLQueryItem(name: "x_platform", value: "ios")
        ]

        if let verifier = verifier {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "code_challenge_method", value: "S256"),
                URLQueryItem(name: "code_challenge", value: verifier.codeChallenge)
            ])
        }

        if let state = self.state {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }

        if let prompt = self.prompt {
            queryItems.append(URLQueryItem(name: "prompt", value: prompt.map { $0.rawValue }.joined(separator: " ")))
        }

        if let loginHint = self.loginHint {
            queryItems.append(URLQueryItem(name: "login_hint", value: loginHint))
        }

        if let idTokenHint = self.idTokenHint {
            queryItems.append(URLQueryItem(name: "id_token_hint", value: idTokenHint))
        }

        if let uiLocales = self.uiLocales {
            queryItems.append(URLQueryItem(
                name: "ui_locales",
                value: uiLocales.joined(separator: " ")
            ))
        }

        if let colorScheme = colorScheme {
            queryItems.append(URLQueryItem(
                name: "x_color_scheme",
                value: colorScheme.rawValue
            ))
        }

        if let maxAge = self.maxAge {
            queryItems.append(URLQueryItem(
                name: "max_age",
                value: String(format: "%d", maxAge)
            ))
        }

        if let wechatRedirectURI = self.wechatRedirectURI {
            queryItems.append(URLQueryItem(
                name: "x_wechat_redirect_uri",
                value: wechatRedirectURI
            ))
        }

        if let page = self.page {
            queryItems.append(URLQueryItem(name: "x_page", value: page.rawValue))
        }

        if self.isSSOEnabled == false {
            // For backward compatibility
            // If the developer updates the SDK but not the server
            queryItems.append(URLQueryItem(name: "x_suppress_idp_session_cookie", value: "true"))
        }

        queryItems.append(URLQueryItem(name: "x_sso_enabled", value: self.isSSOEnabled ? "true" : "false"))

        return queryItems
    }
}

struct OIDCTokenResponse: Decodable {
    let idToken: String?
    let tokenType: String?
    let accessToken: String?
    let expiresIn: Int?
    let refreshToken: String?
}

struct ChallengeBody: Encodable {
    let purpose: String
}

struct ChallengeResponse: Decodable {
    let token: String
    let expireAt: String
}

struct AppSessionTokenBody: Encodable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct AppSessionTokenResponse: Decodable {
    let appSessionToken: String
    let expireAt: String
}

protocol AuthAPIClient: AnyObject {
    var endpoint: URL { get }
    func fetchOIDCConfiguration(handler: @escaping (Result<OIDCConfiguration, Error>) -> Void)
    func requestOIDCToken(
        grantType: GrantType,
        clientId: String,
        deviceInfo: DeviceInfoRoot,
        redirectURI: String?,
        code: String?,
        codeVerifier: String?,
        refreshToken: String?,
        jwt: String?,
        accessToken: String?,
        handler: @escaping (Result<OIDCTokenResponse, Error>) -> Void
    )
    func requestBiometricSetup(
        clientId: String,
        accessToken: String,
        jwt: String,
        handler: @escaping (Result<Void, Error>) -> Void
    )
    func requestOIDCUserInfo(
        accessToken: String,
        handler: @escaping (Result<UserInfo, Error>) -> Void
    )
    func requestOIDCRevocation(
        refreshToken: String,
        handler: @escaping (Result<Void, Error>) -> Void
    )
    func requestOAuthChallenge(
        purpose: String,
        handler: @escaping (Result<ChallengeResponse, Error>) -> Void
    )
    func requestAppSessionToken(
        refreshToken: String,
        handler: @escaping (Result<AppSessionTokenResponse, Error>) -> Void
    )
    func requestWechatAuthCallback(
        code: String,
        state: String,
        handler: @escaping (Result<Void, Error>) -> Void
    )
}

extension AuthAPIClient {
    private func withSemaphore<T>(
        asynTask: (@escaping (Result<T, Error>) -> Void) -> Void
    ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)

        var returnValue: Result<T, Error>?
        asynTask { result in
            returnValue = result
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .distantFuture)
        return try returnValue!.get()
    }

    func syncFetchOIDCConfiguration() throws -> OIDCConfiguration {
        try withSemaphore { handler in
            self.fetchOIDCConfiguration(handler: handler)
        }
    }

    func syncRequestOIDCToken(
        grantType: GrantType,
        clientId: String,
        deviceInfo: DeviceInfoRoot,
        redirectURI: String?,
        code: String?,
        codeVerifier: String?,
        refreshToken: String?,
        jwt: String?,
        accessToken: String?
    ) throws -> OIDCTokenResponse {
        try withSemaphore { handler in
            self.requestOIDCToken(
                grantType: grantType,
                clientId: clientId,
                deviceInfo: deviceInfo,
                redirectURI: redirectURI,
                code: code,
                codeVerifier: codeVerifier,
                refreshToken: refreshToken,
                jwt: jwt,
                accessToken: accessToken,
                handler: handler
            )
        }
    }

    func syncRequestBiometricSetup(
        clientId: String,
        accessToken: String,
        jwt: String
    ) throws {
        try withSemaphore { handler in
            self.requestBiometricSetup(
                clientId: clientId,
                accessToken: accessToken,
                jwt: jwt,
                handler: handler
            )
        }
    }

    func syncRequestOIDCUserInfo(
        accessToken: String
    ) throws -> UserInfo {
        try withSemaphore { handler in
            self.requestOIDCUserInfo(
                accessToken: accessToken,
                handler: handler
            )
        }
    }

    func syncRequestOIDCRevocation(
        refreshToken: String
    ) throws {
        try withSemaphore { handler in
            self.requestOIDCRevocation(
                refreshToken: refreshToken,
                handler: handler
            )
        }
    }

    func syncRequestOAuthChallenge(
        purpose: String
    ) throws -> ChallengeResponse {
        try withSemaphore { handler in
            self.requestOAuthChallenge(
                purpose: purpose,
                handler: handler
            )
        }
    }

    func syncRequestAppSessionToken(
        refreshToken: String
    ) throws -> AppSessionTokenResponse {
        try withSemaphore { handler in
            self.requestAppSessionToken(
                refreshToken: refreshToken,
                handler: handler
            )
        }
    }

    func syncRequestWechatAuthCallback(code: String, state: String) throws {
        try withSemaphore { handler in
            self.requestWechatAuthCallback(
                code: code, state: state,
                handler: handler
            )
        }
    }
}

class DefaultAuthAPIClient: AuthAPIClient {
    public let endpoint: URL

    init(endpoint: URL) {
        self.endpoint = endpoint
    }

    private let defaultSession = URLSession(configuration: .default)
    private var oidcConfiguration: OIDCConfiguration?

    private func buildFetchOIDCConfigurationRequest() -> URLRequest {
        URLRequest(url: endpoint.appendingPathComponent("/.well-known/openid-configuration"))
    }

    func fetchOIDCConfiguration(handler: @escaping (Result<OIDCConfiguration, Error>) -> Void) {
        if let configuration = oidcConfiguration {
            return handler(.success(configuration))
        }

        let request = buildFetchOIDCConfigurationRequest()

        fetch(request: request) { [weak self] (result: Result<OIDCConfiguration, Error>) in
            self?.oidcConfiguration = try? result.get()
            return handler(result)
        }
    }

    func fetch(
        request: URLRequest,
        handler: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void
    ) {
        let dataTaslk = defaultSession.dataTask(with: request) { data, response, error in
            if let error = error {
                return handler(.failure(wrapError(error: error)))
            }

            let response = response as! HTTPURLResponse

            if response.statusCode < 200 || response.statusCode >= 300 {
                if let data = data {
                    let decorder = JSONDecoder()
                    decorder.keyDecodingStrategy = .convertFromSnakeCase
                    if let error = try? decorder.decode(OAuthError.self, from: data) {
                        return handler(.failure(AuthgearError.oauthError(error)))
                    }
                    if let errorResp = try? decorder.decode(APIErrorResponse.self, from: data) {
                        return handler(.failure(AuthgearError.serverError(errorResp.error)))
                    }
                }
                return handler(.failure(AuthgearError.unexpectedHttpStatusCode(response.statusCode, data)))
            }

            return handler(.success((data, response)))
        }

        dataTaslk.resume()
    }

    func fetch<T: Decodable>(
        request: URLRequest,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase,
        handler: @escaping (Result<T, Error>) -> Void
    ) {
        fetch(request: request) { result in
            handler(result.flatMap { (data, _) -> Result<T, Error> in
                do {
                    let decorder = JSONDecoder()
                    decorder.keyDecodingStrategy = keyDecodingStrategy
                    let response = try decorder.decode(T.self, from: data!)
                    return .success(response)
                } catch {
                    return .failure(wrapError(error: error))
                }
            })
        }
    }

    func requestOIDCToken(
        grantType: GrantType,
        clientId: String,
        deviceInfo: DeviceInfoRoot,
        redirectURI: String? = nil,
        code: String? = nil,
        codeVerifier: String? = nil,
        refreshToken: String? = nil,
        jwt: String? = nil,
        accessToken: String? = nil,
        handler: @escaping (Result<OIDCTokenResponse, Error>) -> Void
    ) {
        fetchOIDCConfiguration { [weak self] result in
            switch result {
            case let .success(config):
                let deviceInfoJSON = try! JSONEncoder().encode(deviceInfo)
                let xDeviceInfo = deviceInfoJSON.base64urlEncodedString()

                var queryParams = [String: String]()
                queryParams["client_id"] = clientId
                queryParams["grant_type"] = grantType.rawValue
                queryParams["x_device_info"] = xDeviceInfo

                if let code = code {
                    queryParams["code"] = code
                }

                if let redirectURI = redirectURI {
                    queryParams["redirect_uri"] = redirectURI
                }

                if let codeVerifier = codeVerifier {
                    queryParams["code_verifier"] = codeVerifier
                }

                if let refreshToken = refreshToken {
                    queryParams["refresh_token"] = refreshToken
                }

                if let jwt = jwt {
                    queryParams["jwt"] = jwt
                }

                var urlComponents = URLComponents()
                urlComponents.queryParams = queryParams

                let body = urlComponents.query?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?.data(using: .utf8)

                var urlRequest = URLRequest(url: config.tokenEndpoint)
                if let accessToken = accessToken {
                    urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
                }
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "content-type"
                )
                urlRequest.httpBody = body

                self?.fetch(request: urlRequest, handler: handler)

            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestBiometricSetup(
        clientId: String,
        accessToken: String,
        jwt: String,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        fetchOIDCConfiguration { [weak self] result in
            switch result {
            case let .success(config):
                var queryParams = [String: String]()
                queryParams["client_id"] = clientId
                queryParams["grant_type"] = GrantType.biometric.rawValue
                queryParams["jwt"] = jwt

                var urlComponents = URLComponents()
                urlComponents.queryParams = queryParams

                let body = urlComponents.query?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?.data(using: .utf8)

                var urlRequest = URLRequest(url: config.tokenEndpoint)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "authorization")
                urlRequest.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "content-type"
                )
                urlRequest.httpBody = body

                self?.fetch(request: urlRequest, handler: { result in
                    handler(result.map { _ in () })
                })
            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestOIDCUserInfo(
        accessToken: String,
        handler: @escaping (Result<UserInfo, Error>) -> Void
    ) {
        fetchOIDCConfiguration { [weak self] result in
            switch result {
            case let .success(config):
                var urlRequest = URLRequest(url: config.userinfoEndpoint)
                urlRequest.setValue(
                    "Bearer \(accessToken)",
                    forHTTPHeaderField: "authorization"
                )
                self?.fetch(request: urlRequest, keyDecodingStrategy: .useDefaultKeys, handler: handler)

            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestOIDCRevocation(
        refreshToken: String,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        fetchOIDCConfiguration { [weak self] result in
            switch result {
            case let .success(config):

                var urlComponents = URLComponents()
                urlComponents.queryParams = ["token": refreshToken]

                let body = urlComponents.query?.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)?.data(using: .utf8)

                var urlRequest = URLRequest(url: config.revocationEndpoint)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "content-type"
                )
                urlRequest.httpBody = body

                self?.fetch(request: urlRequest, handler: { result in
                    handler(result.map { _ in () })
                })
            case let .failure(error):
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func requestOAuthChallenge(
        purpose: String,
        handler: @escaping (Result<ChallengeResponse, Error>) -> Void
    ) {
        var urlRequest = URLRequest(url: endpoint.appendingPathComponent("/oauth2/challenge"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try? JSONEncoder().encode(ChallengeBody(purpose: purpose))

        fetch(request: urlRequest, handler: { (result: Result<APIResponse<ChallengeResponse>, Error>) in
            handler(result.flatMap { $0.toResult() })
        })
    }

    func requestAppSessionToken(
        refreshToken: String,
        handler: @escaping (Result<AppSessionTokenResponse, Error>) -> Void
    ) {
        var urlRequest = URLRequest(url: endpoint.appendingPathComponent("/oauth2/app_session_token"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try? JSONEncoder().encode(AppSessionTokenBody(refreshToken: refreshToken))

        fetch(request: urlRequest, handler: { (result: Result<APIResponse<AppSessionTokenResponse>, Error>) in
            handler(result.flatMap { $0.toResult() })
        })
    }

    func requestWechatAuthCallback(code: String, state: String, handler: @escaping (Result<Void, Error>) -> Void) {
        let queryItems = [
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "x_platform", value: "ios")
        ]
        var urlComponents = URLComponents()
        urlComponents.queryItems = queryItems

        let u = endpoint.appendingPathComponent("/sso/wechat/callback")
        var urlRequest = URLRequest(url: u)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "content-type"
        )
        urlRequest.httpBody = urlComponents.query?.data(using: .utf8)
        fetch(request: urlRequest, handler: { result in
            handler(result.map { _ in () })
        })
    }
}
