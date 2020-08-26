//
//  AuthAPIClient.swift
//  Authgear-iOS
//
//  Created by Peter Cheng on 26/8/2020.
//

import Foundation

internal enum AuthAPIClientError: Error {
    case invalidResponse
    case dataTaskError(Error)
    case decodeError(Error)
    case missingEndpoint
    case serverError(ServerError)
    case statusCode(Int, Data?)
    case oidcError(OIDCError)
}

internal enum GrantType: String {
    case authorizationCode = "authorization_code"
    case refreshToken = "refresh_token"
    case anonymous = "urn:authgear:params:oauth:grant-type:anonymous-request"
}

enum IntParsingError: Error {
    case invalidInput(String)
}

internal struct OIDCError: Error, Decodable {
    let error: String
    let errorDescription: String
}

internal struct ServerError: Error, Decodable {
    let name: String
    let message: String
    let reason: String
    let info: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case name
        case message
        case reason
        case info
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try values.decode(String.self, forKey: .name)
        self.message = try values.decode(String.self, forKey: .message)
        self.reason = try values.decode(String.self, forKey: .reason)
        self.info = try values.decode([String: Any].self, forKey: .info)
    }
}

internal enum APIResponse<T: Decodable>: Decodable {
    case result(T)
    case error(ServerError)

    enum CodingKeys: String, CodingKey {
        case result
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if container.contains(.error) {
            self = .error(try container.decode(ServerError.self, forKey: .error))
        } else {
            self = .result(try container.decode(T.self, forKey: .result))
        }
    }

    func toResult() -> Result<T, Error> {
        switch self {
        case .result(let value):
            return .success(value)
        case .error(let error):
            return .failure(AuthAPIClientError.serverError(error))
        }
    }
}

internal struct TokenResponse: Decodable {
    let idToken: String?
    let tokenType: String
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case idToken
        case tokenType
        case accessToken
        case expiresIn
        case refreshToken
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.idToken = try values.decodeIfPresent(String.self, forKey: .idToken)
        self.tokenType = try values.decode(String.self, forKey: .tokenType)
        self.accessToken = try values.decode(String.self, forKey: .accessToken)

        let expiresInIntValue = try? values.decode(Int.self, forKey: .expiresIn)
        if let expiresInIntValue = expiresInIntValue {
            self.expiresIn = expiresInIntValue
        } else {
            let expiresInValue = try values.decode(String.self, forKey: .expiresIn)
            if let expiresIn = Int(expiresInValue) {
                self.expiresIn = expiresIn
            } else {
                throw IntParsingError.invalidInput(expiresInValue)
            }
        }
        self.refreshToken = try values.decodeIfPresent(String.self, forKey: .refreshToken)
    }
}

internal struct ChallengeBody: Encodable {
    let purpose: String
}

internal struct ChallengeResponse: Decodable {
    let token: String
    let expireAt: String
}

internal protocol AuthAPIClient: class {
    var endpoint: URL? { get set }
    func fetchOIDCConfiguration(handler: @escaping (Result<OIDCConfiguration, Error>) -> Void)
    func requestOIDCToken(
        grantType: GrantType,
        clientId: String,
        redirectURI: String?,
        code: String?,
        codeVerifier: String?,
        refreshToken: String?,
        jwt: String?,
        handler: @escaping (Result<TokenResponse, Error>) -> Void
    )
    func requestOIDCUserInfo(
        accessToken: String?,
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
        return try withSemaphore { handler in
            self.fetchOIDCConfiguration(handler: handler)
        }
    }

    func syncRequestOIDCToken(
        grantType: GrantType,
        clientId: String,
        redirectURI: String?,
        code: String?,
        codeVerifier: String?,
        refreshToken: String?,
        jwt: String?
    ) throws -> TokenResponse {
        return try withSemaphore { handler in
            self.requestOIDCToken(
                grantType: grantType,
                clientId: clientId,
                redirectURI: redirectURI,
                code: code,
                codeVerifier: codeVerifier,
                refreshToken: refreshToken,
                jwt: jwt,
                handler: handler
            )
        }
    }

    func syncRequestOIDCUserInfo(
        accessToken: String?
    ) throws -> UserInfo {
        return try withSemaphore { handler in
            self.requestOIDCUserInfo(
                accessToken: accessToken,
                handler: handler
            )
        }
    }

    func syncRequestOIDCRevocation(
        refreshToken: String
    ) throws {
        return try withSemaphore { handler in
            self.requestOIDCRevocation(
                refreshToken: refreshToken,
                handler: handler
            )
        }
    }

    func syncRequestOAuthChallenge(
        purpose: String
    ) throws -> ChallengeResponse {
        return try withSemaphore { handler in
            self.requestOAuthChallenge(
                purpose: purpose,
                handler: handler
            )
        }
    }
}

internal protocol AuthAPIClientDelegate: class {
    func getAccessToken() -> String?
    func shouldRefreshAccessToken() -> Bool
    func refreshAccessToken(handler: VoidCompletionHandler?)
}

internal class DefaultAuthAPIClient: AuthAPIClient {
    public var endpoint: URL?

    private let defaultSession = URLSession(configuration: .default)
    private var oidcConfiguration: OIDCConfiguration?

    internal weak var delegate: AuthAPIClientDelegate?

    private func buildFetchOIDCConfigurationRequest() -> URLRequest? {
        guard let endpoint = self.endpoint else {
            return nil
        }
        return URLRequest(url: endpoint.appendingPathComponent("/.well-known/openid-configuration"))
    }

    internal func fetchOIDCConfiguration(handler: @escaping (Result<OIDCConfiguration, Error>) -> Void) {

        if let configuration = self.oidcConfiguration {
            return handler(.success(configuration))
        }

        guard let request = buildFetchOIDCConfigurationRequest() else {
            return handler(.failure(AuthAPIClientError.missingEndpoint))
        }

        self.fetch(request: request) { [weak self] (result: Result<OIDCConfiguration, Error>) in
            self?.oidcConfiguration = try? result.get()
            return handler(result)
        }
    }

    internal func fetch(
        request: URLRequest,
        handler: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void
    ) {
        let dataTaslk = self.defaultSession.dataTask(with: request) { (data, response, error) in

            guard let response = response as? HTTPURLResponse else {
                return handler(.failure(AuthAPIClientError.invalidResponse))
            }

            if response.statusCode < 200 || response.statusCode >= 300 {
                if let data = data {
                    let decorder = JSONDecoder()
                    decorder.keyDecodingStrategy = .convertFromSnakeCase
                    if let error = try? decorder.decode(OIDCError.self, from: data) {
                        return handler(.failure(AuthAPIClientError.oidcError(error)))
                    }
                }
                return handler(.failure(AuthAPIClientError.statusCode(response.statusCode, data)))
            }

            if let error = error {
                return handler(.failure(AuthAPIClientError.dataTaskError(error)))
            }

            return handler(.success((data, response)))
        }

        dataTaslk.resume()
    }

    internal func fetch<T: Decodable>(
        request: URLRequest,
        keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .convertFromSnakeCase,
        handler: @escaping (Result<T, Error>) -> Void) {

        self.fetch(request: request) { result in
            handler(result.flatMap { (data, _) -> Result<T, Error> in
                do {
                    let decorder = JSONDecoder()
                    decorder.keyDecodingStrategy = keyDecodingStrategy
                    let response = try decorder.decode(T.self, from: data!)
                    return .success(response)
                } catch {
                    return .failure(AuthAPIClientError.decodeError(error))
                }
            })
        }
    }

    internal func refreshAccessTokenIfNeeded(handler: @escaping (Result<Void, Error>) -> Void) {
        if let delegate = self.delegate,
            delegate.shouldRefreshAccessToken() {
            delegate.refreshAccessToken { result in
                switch result {
                case .success:
                    return handler(.success(()))
                case .failure(let error):
                    return handler(.failure(error))
                }
            }
        }
        return handler(.success(()))
    }

    internal func fetchWithRefreshToken(
        request: URLRequest,
        handler: @escaping (Result<(Data?, HTTPURLResponse), Error>) -> Void
    ) {

        self.refreshAccessTokenIfNeeded { [weak self] result in
            switch result {
            case .success:
                var request = request
                if let accessToken = self?.delegate?.getAccessToken() {
                    request.setValue("bearer \(accessToken)", forHTTPHeaderField: "authorization")
                }

                self?.fetch(request: request, handler: handler)
            case .failure(let error):
                return handler(.failure(error))
            }
        }
    }

    internal func requestOIDCToken(
        grantType: GrantType,
        clientId: String,
        redirectURI: String? = nil,
        code: String? = nil,
        codeVerifier: String? = nil,
        refreshToken: String? = nil,
        jwt: String? = nil,
        handler: @escaping (Result<TokenResponse, Error>) -> Void
    ) {
        self.fetchOIDCConfiguration { [weak self] result in
            switch result {
            case .success(let config):
                var queryParams = [String: String]()
                queryParams["client_id"] = clientId
                queryParams["grant_type"] = grantType.rawValue

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
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(
                    "application/x-www-form-urlencoded",
                    forHTTPHeaderField: "content-type"
                )
                urlRequest.httpBody = body

                self?.fetch(request: urlRequest, handler: handler)

            case .failure(let error):
                return handler(.failure(error))
            }

        }
    }

    func requestOIDCUserInfo(
        accessToken: String? = nil,
        handler: @escaping (Result<UserInfo, Error>) -> Void
    ) {
        self.fetchOIDCConfiguration { [weak self] result in
            switch result {
            case .success(let config):
                var urlRequest = URLRequest(url: config.userinfoEndpoint)
                if let accessToken = accessToken {
                    urlRequest.setValue(
                        "bearer \(accessToken)",
                        forHTTPHeaderField: "authorization"
                    )
                }
                self?.fetch(request: urlRequest, keyDecodingStrategy: .useDefaultKeys, handler: handler)

            case .failure(let error):
                return handler(.failure(error))
            }

        }
    }

    func requestOIDCRevocation(
        refreshToken: String,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        self.fetchOIDCConfiguration { [weak self] result in
            switch result {
            case .success(let config):

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
                    handler(result.map { _ in ()})
                })
            case .failure(let error):
                return handler(.failure(error))
            }
        }
    }

    func requestOAuthChallenge(
        purpose: String,
        handler: @escaping (Result<ChallengeResponse, Error>) -> Void
    ) {

        guard let endpoint = self.endpoint else {
            return handler(.failure(AuthAPIClientError.missingEndpoint))
        }

        var urlRequest = URLRequest(url: endpoint.appendingPathComponent("/oauth2/challenge"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try? JSONEncoder().encode(ChallengeBody(purpose: purpose))

        self.fetch(request: urlRequest, handler: { (result: Result<APIResponse<ChallengeResponse>, Error>) in
            return handler(result.flatMap { $0.toResult() })
        })
    }
}

