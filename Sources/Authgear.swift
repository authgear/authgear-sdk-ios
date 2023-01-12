import AuthenticationServices
import Foundation
import LocalAuthentication
import SafariServices
import Security
import WebKit

public typealias UserInfoCompletionHandler = (Result<UserInfo, Error>) -> Void
public typealias VoidCompletionHandler = (Result<Void, Error>) -> Void

public enum PromptOption: String {
    case none
    case login
    case consent
    case selectAccount = "select_account"
}

struct AuthenticateOptions {
    let redirectURI: String
    let isSSOEnabled: Bool
    let state: String?
    let prompt: [PromptOption]?
    let loginHint: String?
    let uiLocales: [String]?
    let colorScheme: ColorScheme?
    let wechatRedirectURI: String?
    let page: AuthenticationPage?
    let customUIQuery: String?

    var request: OIDCAuthenticationRequest {
        OIDCAuthenticationRequest(
            redirectURI: self.redirectURI,
            responseType: "code",
            scope: ["openid", "offline_access", "https://authgear.com/scopes/full-access"],
            isSSOEnabled: isSSOEnabled,
            state: self.state,
            prompt: self.prompt,
            loginHint: self.loginHint,
            uiLocales: self.uiLocales,
            colorScheme: self.colorScheme,
            idTokenHint: nil,
            maxAge: nil,
            wechatRedirectURI: self.wechatRedirectURI,
            page: self.page,
            customUIQuery: self.customUIQuery
        )
    }
}

struct ReauthenticateOptions {
    let redirectURI: String
    let isSSOEnabled: Bool
    let state: String?
    let uiLocales: [String]?
    let colorScheme: ColorScheme?
    let wechatRedirectURI: String?
    let maxAge: Int?
    let customUIQuery: String?

    func toRequest(idTokenHint: String) -> OIDCAuthenticationRequest {
        OIDCAuthenticationRequest(
            redirectURI: self.redirectURI,
            responseType: "code",
            scope: ["openid", "https://authgear.com/scopes/full-access"],
            isSSOEnabled: isSSOEnabled,
            state: self.state,
            prompt: nil,
            loginHint: nil,
            uiLocales: self.uiLocales,
            colorScheme: self.colorScheme,
            idTokenHint: idTokenHint,
            maxAge: self.maxAge ?? 0,
            wechatRedirectURI: self.wechatRedirectURI,
            page: nil,
            customUIQuery: self.customUIQuery
        )
    }
}

public struct UserInfoAddress: Decodable {
    enum CodingKeys: String, CodingKey {
        case formatted
        case streetAddress = "street_address"
        case locality
        case region
        case postalCode = "postal_code"
        case country
    }

    public let formatted: String?
    public let streetAddress: String?
    public let locality: String?
    public let region: String?
    public let postalCode: String?
    public let country: String?
}

public struct UserInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case sub
        case isAnonymous = "https://authgear.com/claims/user/is_anonymous"
        case isVerified = "https://authgear.com/claims/user/is_verified"
        case canReauthenticate = "https://authgear.com/claims/user/can_reauthenticate"
        case customAttributes = "custom_attributes"
        case email
        case emailVerified = "email_verified"
        case phoneNumber = "phone_number"
        case phoneNumberVerified = "phone_number_verified"
        case preferredUsername = "preferred_username"
        case familyName = "family_name"
        case givenName = "given_name"
        case middleName = "middle_name"
        case name
        case nickname
        case picture
        case profile
        case website
        case gender
        case birthdate
        case zoneinfo
        case locale
        case address
    }

    public let sub: String
    public let isAnonymous: Bool
    public let isVerified: Bool
    public let canReauthenticate: Bool

    public let customAttributes: [String: Any]

    public let email: String?
    public let emailVerified: Bool?
    public let phoneNumber: String?
    public let phoneNumberVerified: Bool?
    public let preferredUsername: String?
    public let familyName: String?
    public let givenName: String?
    public let middleName: String?
    public let name: String?
    public let nickname: String?
    public let picture: String?
    public let profile: String?
    public let website: String?
    public let gender: String?
    public let birthdate: String?
    public let zoneinfo: String?
    public let locale: String?
    public let address: UserInfoAddress?

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        self.sub = try values.decode(String.self, forKey: .sub)
        self.isAnonymous = try values.decode(Bool.self, forKey: .isAnonymous)
        self.isVerified = try values.decode(Bool.self, forKey: .isVerified)
        self.canReauthenticate = try values.decode(Bool.self, forKey: .canReauthenticate)

        self.email = try values.decodeIfPresent(String.self, forKey: .email)
        self.emailVerified = try values.decodeIfPresent(Bool.self, forKey: .emailVerified)
        self.phoneNumber = try values.decodeIfPresent(String.self, forKey: .phoneNumber)
        self.phoneNumberVerified = try values.decodeIfPresent(Bool.self, forKey: .phoneNumberVerified)
        self.preferredUsername = try values.decodeIfPresent(String.self, forKey: .preferredUsername)
        self.familyName = try values.decodeIfPresent(String.self, forKey: .familyName)
        self.givenName = try values.decodeIfPresent(String.self, forKey: .givenName)
        self.middleName = try values.decodeIfPresent(String.self, forKey: .middleName)
        self.name = try values.decodeIfPresent(String.self, forKey: .name)
        self.nickname = try values.decodeIfPresent(String.self, forKey: .nickname)
        self.picture = try values.decodeIfPresent(String.self, forKey: .picture)
        self.profile = try values.decodeIfPresent(String.self, forKey: .profile)
        self.website = try values.decodeIfPresent(String.self, forKey: .website)
        self.gender = try values.decodeIfPresent(String.self, forKey: .gender)
        self.birthdate = try values.decodeIfPresent(String.self, forKey: .birthdate)
        self.zoneinfo = try values.decodeIfPresent(String.self, forKey: .zoneinfo)
        self.locale = try values.decodeIfPresent(String.self, forKey: .locale)
        self.address = try values.decodeIfPresent(UserInfoAddress.self, forKey: .address)
        self.customAttributes = try values.decode([String: Any].self, forKey: .customAttributes)
    }
}

public enum SessionState: String {
    case unknown = "UNKNOWN"
    case noSession = "NO_SESSION"
    case authenticated = "AUTHENTICATED"
}

public enum ColorScheme: String {
    case light
    case dark
}

public enum AuthenticationPage: String {
    case login
    case signup
}

public enum SettingsPage: String {
    case settings = "/settings"
    case identity = "/settings/identities"
}

public enum SessionStateChangeReason: String {
    case noToken = "NO_TOKEN"
    case foundToken = "FOUND_TOKEN"
    case authenticated = "AUTHENTICATED"
    case logout = "LOGOUT"
    case invalid = "INVALID"
    case clear = "CLEAR"
}

public enum UIVariant: String {
    case asWebAuthenticationSession
    case wkWebView
    case wkWebViewFullScreen
}

public protocol AuthgearDelegate: AnyObject {
    func authgearSessionStateDidChange(_ container: Authgear, reason: SessionStateChangeReason)
    func sendWechatAuthRequest(_ state: String)
}

public extension AuthgearDelegate {
    func authgearSessionStateDidChange(_ container: Authgear, reason: SessionStateChangeReason) {}
    func sendWechatAuthRequest(_ state: String) {}
}

public class Authgear {
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
    let clientId: String
    let apiClient: AuthAPIClient
    let storage: ContainerStorage
    var tokenStorage: TokenStorage
    public let isSSOEnabled: Bool
    public let uiVariant: UIVariant

    private let authenticationSessionProvider = AuthenticationSessionProvider()
    private var authenticationSession: AuthenticationSession?

    public private(set) var accessToken: String?
    private var refreshToken: String?
    private var expireAt: Date?

    private var idToken: String?

    public var idTokenHint: String? {
        self.idToken
    }

    public var canReauthenticate: Bool {
        guard let idToken = self.idToken else { return false }
        do {
            let payload = try JWT.decode(jwt: idToken)
            if let can = payload["https://authgear.com/claims/user/can_reauthenticate"] as? Bool {
                return can
            }
            return false
        } catch {
            return false
        }
    }

    public var authTime: Date? {
        guard let idToken = self.idToken else { return nil }
        do {
            let payload = try JWT.decode(jwt: idToken)
            if let unixEpoch = payload["auth_time"] as? NSNumber {
                return Date(timeIntervalSince1970: unixEpoch.doubleValue)
            }
            return nil
        } catch {
            return nil
        }
    }

    private let jwkStore = JWKStore()
    private let workerQueue: DispatchQueue

    private var currentWechatRedirectURI: String?

    public private(set) var sessionState: SessionState = .unknown

    public weak var delegate: AuthgearDelegate?

    public init(clientId: String, endpoint: String, tokenStorage: TokenStorage = PersistentTokenStorage(), isSSOEnabled: Bool = false, uiVariant: UIVariant = .asWebAuthenticationSession, name: String? = nil) {
        self.clientId = clientId
        self.name = name ?? "default"
        self.tokenStorage = tokenStorage
        self.storage = PersistentContainerStorage()
        self.isSSOEnabled = isSSOEnabled
        self.uiVariant = uiVariant
        self.apiClient = DefaultAuthAPIClient(endpoint: URL(string: endpoint)!)
        self.workerQueue = DispatchQueue(label: "authgear:\(self.name)", qos: .utility)
    }

    public func configure(
        handler: VoidCompletionHandler? = nil
    ) {
        workerQueue.async {
            let refreshToken = Result { try self.tokenStorage.getRefreshToken(namespace: self.name) }
            switch refreshToken {
            case let .success(token):
                DispatchQueue.main.async {
                    self.refreshToken = token
                    self.setSessionState(token == nil ? .noSession : .authenticated, reason: .foundToken)
                    handler?(.success(()))
                }

            case let .failure(error):
                DispatchQueue.main.async {
                    handler?(.failure(wrapError(error: error)))
                }
            }
        }
    }

    private func setSessionState(_ newState: SessionState, reason: SessionStateChangeReason) {
        sessionState = newState
        delegate?.authgearSessionStateDidChange(self, reason: reason)
    }

    private func buildAuthorizationURL(request: OIDCAuthenticationRequest, verifier: CodeVerifier?) throws -> URL {
        let configuration = try apiClient.syncFetchOIDCConfiguration()
        let queryItems = request.toQueryItems(clientID: self.clientId, verifier: verifier)
        var urlComponents = URLComponents(
            url: configuration.authorizationEndpoint,
            resolvingAgainstBaseURL: false
        )!
        urlComponents.queryItems = queryItems
        return urlComponents.url!
    }

    private func reauthenticateWithASWebAuthenticationSession(
        _ options: ReauthenticateOptions,
        handler: @escaping UserInfoCompletionHandler
    ) {
        do {
            guard let idTokenHint = self.idTokenHint else {
                throw AuthgearError.unauthenticatedUser
            }
            let request = options.toRequest(idTokenHint: idTokenHint)
            let verifier = CodeVerifier()
            let url = try self.buildAuthorizationURL(request: request, verifier: verifier)
            let prefersEphemeralWebBrowserSession = self.shouldASWebAuthenticationSessionPrefersEphemeralWebBrowserSession()

            DispatchQueue.main.async {
                self.registerCurrentWechatRedirectURI(uri: options.wechatRedirectURI)
                self.authenticationSession = self.authenticationSessionProvider.makeAuthenticationSession(
                    url: url,
                    redirectURI: request.redirectURI,
                    prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
                    uiVariant: self.uiVariant,
                    completionHandler: { [weak self] result in
                        self?.unregisterCurrentWechatRedirectURI()
                        switch result {
                        case let .success(url):
                            self?.workerQueue.async {
                                self?.finishReauthentication(url: url, verifier: verifier, handler: handler)
                            }
                        case let .failure(error):
                            return handler(.failure(wrapError(error: error)))
                        }
                    }
                )
                self.authenticationSession?.start()
            }
        } catch {
            handler(.failure(wrapError(error: error)))
        }
    }

    private func authenticateWithASWebAuthenticationSession(
        _ options: AuthenticateOptions,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let verifier = CodeVerifier()
        let request = options.request
        let url = Result { try self.buildAuthorizationURL(request: request, verifier: verifier) }
        let prefersEphemeralWebBrowserSession = self.shouldASWebAuthenticationSessionPrefersEphemeralWebBrowserSession()

        DispatchQueue.main.async {
            switch url {
            case let .success(url):
                self.registerCurrentWechatRedirectURI(uri: options.wechatRedirectURI)
                self.authenticationSession = self.authenticationSessionProvider.makeAuthenticationSession(
                    url: url,
                    redirectURI: request.redirectURI,
                    prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession,
                    uiVariant: self.uiVariant,
                    completionHandler: { [weak self] result in
                        self?.unregisterCurrentWechatRedirectURI()
                        switch result {
                        case let .success(url):
                            self?.workerQueue.async {
                                self?.finishAuthentication(url: url, verifier: verifier, handler: handler)
                            }
                        case let .failure(error):
                            return handler(.failure(wrapError(error: error)))
                        }
                    }
                )
                self.authenticationSession?.start()
            case let .failure(error):
                handler(.failure(wrapError(error: error)))
            }
        }
    }

    private func finishAuthentication(
        url: URL,
        verifier: CodeVerifier,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let params = urlComponents.queryParams

        if let errorParams = params["error"] {
            return handler(
                .failure(AuthgearError.oauthError(
                    OAuthError(
                        error: errorParams,
                        errorDescription: params["error_description"],
                        errorUri: params["error_uri"]
                    )
                ))
            )
        }

        guard let code = params["code"] else {
            return handler(
                .failure(AuthgearError.oauthError(
                    OAuthError(
                        error: "invalid_request",
                        errorDescription: "Missing parameter: code",
                        errorUri: nil
                    )
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
                deviceInfo: getDeviceInfo(),
                redirectURI: redirectURI,
                code: code,
                codeVerifier: verifier.value,
                refreshToken: nil,
                jwt: nil,
                accessToken: nil
            )

            let userInfo = try apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken!)

            let result = persistSession(oidcTokenResponse, reason: .authenticated)
                .flatMap {
                    Result { () in
                        if #available(iOS 11.3, *) {
                            try self.disableBiometric()
                        }
                    }
                }
                .map { userInfo }
            return handler(result)

        } catch {
            return handler(.failure(wrapError(error: error)))
        }
    }

    private func finishReauthentication(
        url: URL,
        verifier: CodeVerifier,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let params = urlComponents.queryParams

        if let errorParams = params["error"] {
            return handler(
                .failure(AuthgearError.oauthError(
                    OAuthError(
                        error: errorParams,
                        errorDescription: params["error_description"],
                        errorUri: params["error_uri"]
                    )
                ))
            )
        }

        guard let code = params["code"] else {
            return handler(
                .failure(AuthgearError.oauthError(
                    OAuthError(
                        error: "invalid_request",
                        errorDescription: "Missing parameter: code",
                        errorUri: nil
                    )
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
                deviceInfo: getDeviceInfo(),
                redirectURI: redirectURI,
                code: code,
                codeVerifier: verifier.value,
                refreshToken: nil,
                jwt: nil,
                accessToken: nil
            )

            let userInfo = try apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken!)

            if let idToken = oidcTokenResponse.idToken {
                self.idToken = idToken
            }

            return handler(.success(userInfo))
        } catch {
            return handler(.failure(wrapError(error: error)))
        }
    }

    private func persistSession(_ oidcTokenResponse: OIDCTokenResponse, reason: SessionStateChangeReason) -> Result<Void, Error> {
        if let refreshToken = oidcTokenResponse.refreshToken {
            let result = Result { try self.tokenStorage.setRefreshToken(namespace: self.name, token: refreshToken) }
            guard case .success = result else {
                return result
            }
        }

        DispatchQueue.main.async {
            self.accessToken = oidcTokenResponse.accessToken
            if let refreshToken = oidcTokenResponse.refreshToken {
                self.refreshToken = refreshToken
            }
            if let idToken = oidcTokenResponse.idToken {
                self.idToken = idToken
            }
            self.expireAt = Date(timeIntervalSinceNow: TimeInterval(Double(oidcTokenResponse.expiresIn!) * Authgear.ExpireInPercentage))
            self.setSessionState(.authenticated, reason: reason)
        }
        return .success(())
    }

    private func cleanupSession(force: Bool, reason: SessionStateChangeReason) -> Result<Void, Error> {
        if case let .failure(error) = Result(catching: { try tokenStorage.delRefreshToken(namespace: name) }) {
            if !force {
                return .failure(wrapError(error: error))
            }
        }
        if case let .failure(error) = Result(catching: { try storage.delAnonymousKeyId(namespace: name) }) {
            if !force {
                return .failure(wrapError(error: error))
            }
        }

        DispatchQueue.main.async {
            self.accessToken = nil
            self.refreshToken = nil
            self.idToken = nil
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

    private func registerCurrentWechatRedirectURI(uri: String?) {
        currentWechatRedirectURI = uri
    }

    private func unregisterCurrentWechatRedirectURI() {
        currentWechatRedirectURI = nil
    }

    private func handleWechatRedirectURI(_ url: URL) -> Bool {
        if currentWechatRedirectURI == nil {
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

        if urlWithoutQuery == currentWechatRedirectURI {
            delegate?.sendWechatAuthRequest(state!)
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
            _ = handleWechatRedirectURI(url)
        }
        return true
    }

    @available(iOS 13.0, *)
    public func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return
        }
        _ = handleWechatRedirectURI(url)
    }

    public func authenticate(
        redirectURI: String,
        state: String? = nil,
        prompt: [PromptOption]? = nil,
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        page: AuthenticationPage? = nil,
        customUIQuery: String? = nil,
        handler: @escaping UserInfoCompletionHandler
    ) {
        self.authenticate(AuthenticateOptions(
            redirectURI: redirectURI,
            isSSOEnabled: self.isSSOEnabled,
            state: state,
            prompt: prompt,
            loginHint: loginHint,
            uiLocales: uiLocales,
            colorScheme: colorScheme,
            wechatRedirectURI: wechatRedirectURI,
            page: page,
            customUIQuery: customUIQuery
        ), handler: handler)
    }

    private func authenticate(
        _ options: AuthenticateOptions,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let handler = self.withMainQueueHandler(handler)
        self.workerQueue.async {
            self.authenticateWithASWebAuthenticationSession(options, handler: handler)
        }
    }

    public func reauthenticate(
        redirectURI: String,
        state: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        maxAge: Int? = nil,
        localizedReason: String? = nil,
        policy: BiometricLAPolicy? = nil,
        customUIQuery: String? = nil,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let handler = self.withMainQueueHandler(handler)

        do {
            if #available(iOS 11.3, *) {
                let biometricEnabled = try self.isBiometricEnabled()
                if let localizedReason = localizedReason, let policy = policy, biometricEnabled {
                    self.authenticateBiometric(localizedReason: localizedReason, policy: policy) { result in
                        switch result {
                        case let .success(userInfo):
                            handler(.success(userInfo))
                        case let .failure(error):
                            handler(.failure(wrapError(error: error)))
                        }
                    }
                    // Return here to prevent us from continue
                    return
                }
            }
        } catch {
            handler(.failure(wrapError(error: error)))
            // Return here to prevent us from continue
            return
        }

        if !self.canReauthenticate {
            handler(.failure(AuthgearError.cannotReauthenticate))
            return
        }

        let options = ReauthenticateOptions(
            redirectURI: redirectURI,
            isSSOEnabled: self.isSSOEnabled,
            state: state,
            uiLocales: uiLocales,
            colorScheme: colorScheme,
            wechatRedirectURI: wechatRedirectURI,
            maxAge: maxAge,
            customUIQuery: customUIQuery
        )

        self.workerQueue.async {
            self.reauthenticateWithASWebAuthenticationSession(options, handler: handler)
        }
    }

    public func authenticateAnonymously(
        handler: @escaping UserInfoCompletionHandler
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
                    deviceInfo: getDeviceInfo(),
                    redirectURI: nil,
                    code: nil,
                    codeVerifier: nil,
                    refreshToken: nil,
                    jwt: signedJWT,
                    accessToken: nil
                )

                let userInfo = try self.apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken!)

                let result = self.persistSession(oidcTokenResponse, reason: .authenticated)
                    .flatMap {
                        Result { () in
                            try self.storage.setAnonymousKeyId(namespace: self.name, kid: keyId)
                            if #available(iOS 11.3, *) {
                                try self.disableBiometric()
                            }
                        }
                    }
                    .map { userInfo }
                handler(result)

            } catch {
                handler(.failure(wrapError(error: error)))
            }
        }
    }

    public func promoteAnonymousUser(
        redirectURI: String,
        state: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        handler: @escaping UserInfoCompletionHandler
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

                self.authenticate(
                    AuthenticateOptions(
                        redirectURI: redirectURI,
                        isSSOEnabled: self.isSSOEnabled,
                        state: state,
                        prompt: [.login],
                        loginHint: loginHint,
                        uiLocales: uiLocales,
                        colorScheme: colorScheme,
                        wechatRedirectURI: wechatRedirectURI,
                        page: nil,
                        customUIQuery: nil
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
                        handler(.failure(wrapError(error: error)))
                    }
                }
            } catch {
                handler(.failure(wrapError(error: error)))
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
                let token = try self.tokenStorage.getRefreshToken(
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
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    public func openURL(
        path: String,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        handler: VoidCompletionHandler? = nil
    ) {
        let handler = handler.map { h in withMainQueueHandler(h) }

        var urlComponents = URLComponents(url: apiClient.endpoint.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        var queryItems = urlComponents.queryItems ?? []
        if let uiLocales = uiLocales {
            queryItems.append(URLQueryItem(
                name: "ui_locales",
                value: uiLocales.joined(separator: " ")
            ))
        }
        if let colorScheme = colorScheme {
            queryItems.append(URLQueryItem(name: "x_color_scheme", value: colorScheme.rawValue))
        }
        urlComponents.queryItems = queryItems
        let url = urlComponents.url!

        workerQueue.async {
            do {
                guard let refreshToken = try self.tokenStorage.getRefreshToken(namespace: self.name) else {
                    handler?(.failure(AuthgearError.unauthenticatedUser))
                    return
                }

                var token = ""
                do {
                    token = try self.apiClient.syncRequestAppSessionToken(refreshToken: refreshToken).appSessionToken
                } catch {
                    _ = self._handleInvalidGrantException(error: error)
                    handler?(.failure(wrapError(error: error)))
                    return
                }

                let loginHint = "https://authgear.com/login_hint?type=app_session_token&app_session_token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

                let endpoint = try self.buildAuthorizationURL(request: OIDCAuthenticationRequest(
                    redirectURI: url.absoluteString,
                    responseType: "none",
                    scope: ["openid", "offline_access", "https://authgear.com/scopes/full-access"],
                    isSSOEnabled: self.isSSOEnabled,
                    state: nil,
                    prompt: [.none],
                    loginHint: loginHint,
                    uiLocales: uiLocales,
                    colorScheme: colorScheme,
                    idTokenHint: nil,
                    maxAge: nil,
                    wechatRedirectURI: wechatRedirectURI,
                    page: nil,
                    customUIQuery: nil
                ), verifier: nil)

                DispatchQueue.main.async {
                    // For opening setting page, sdk will not know when user end
                    // the setting page.
                    // So we cannot unregister the wechat uri in this case
                    // It is fine to not unresgister it, as everytime we open a
                    // new authorize section (authorize or setting page)
                    // registerCurrentWeChatRedirectURI will be called and overwrite
                    // previous registered wechatRedirectURI
                    self.registerCurrentWechatRedirectURI(uri: wechatRedirectURI)
                    self.authenticationSession = self.authenticationSessionProvider.makeAuthenticationSession(
                        url: endpoint,
                        // Opening an arbitrary URL does not have a clear goal.
                        // So here we pass a placeholder redirect uri.
                        redirectURI: "nocallback",
                        // prefersEphemeralWebBrowserSession is true so that
                        // the alert dialog is never prompted and
                        // the app session token cookie is forgotten when the webview is closed.
                        prefersEphemeralWebBrowserSession: true,
                        uiVariant: self.uiVariant,
                        completionHandler: { [weak self] result in
                            self?.unregisterCurrentWechatRedirectURI()
                            switch result {
                            case .success:
                                // This branch is unreachable.
                                handler?(.success(()))
                            case let .failure(error):
                                if case AuthgearError.cancel = error {
                                    handler?(.success(()))
                                } else {
                                    handler?(.failure(wrapError(error: error)))
                                }
                            }
                        }
                    )
                    self.authenticationSession?.start()
                }
            } catch {
                handler?(.failure(wrapError(error: error)))
            }
        }
    }

    public func open(
        page: SettingsPage,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil
    ) {
        openURL(
            path: page.rawValue,
            uiLocales: uiLocales,
            colorScheme: colorScheme,
            wechatRedirectURI: wechatRedirectURI
        )
    }

    private func shouldASWebAuthenticationSessionPrefersEphemeralWebBrowserSession() -> Bool {
        !self.isSSOEnabled
    }

    private func shouldRefreshAccessToken() -> Bool {
        // 1. We must have refresh token.
        guard refreshToken != nil else { return false }

        // 2.1 Either the access token is not present, e.g. just right after configure()
        if case .none = self.accessToken, case .none = self.expireAt {
            return true
        }

        // 2.2 Or the access token is about to expire.
        if let _ = self.accessToken, let expireAt = self.expireAt {
            return expireAt.timeIntervalSinceNow.sign == .minus
        }

        return false
    }

    private func refreshAccessToken(handler: VoidCompletionHandler? = nil) {
        let handler = handler.map { h in withMainQueueHandler(h) }
        workerQueue.async {
            do {
                guard let refreshToken = try self.tokenStorage.getRefreshToken(namespace: self.name) else {
                    let result = self.cleanupSession(force: true, reason: .noToken)
                    handler?(result)
                    return
                }

                let oidcTokenResponse = try self.apiClient.syncRequestOIDCToken(
                    grantType: GrantType.refreshToken,
                    clientId: self.clientId,
                    deviceInfo: getDeviceInfo(),
                    redirectURI: nil,
                    code: nil,
                    codeVerifier: nil,
                    refreshToken: refreshToken,
                    jwt: nil,
                    accessToken: nil
                )

                let result = self.persistSession(oidcTokenResponse, reason: .foundToken)
                handler?(result)
            } catch {
                let result = self._handleInvalidGrantException(error: error)
                if let error = error as? AuthgearError,
                   case let .oauthError(oauthError) = error,
                   oauthError.error == "invalid_grant" {
                    handler?(result)
                    return
                }
                handler?(.failure(wrapError(error: error)))
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

    public func clearSessionState(
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
                if case let .failure(error) = result {
                    _ = self._handleInvalidGrantException(error: error)
                }
                handler(result)
            }
        }

        refreshAccessTokenIfNeeded { _ in
            fetchUserInfo(self.accessToken ?? "")
        }
    }

    public func refreshIDToken(handler: @escaping VoidCompletionHandler) {
        let handler = withMainQueueHandler(handler)
        let task = {
            self.workerQueue.async {
                do {
                    let oidcTokenResponse = try self.apiClient.syncRequestOIDCToken(
                        grantType: .idToken,
                        clientId: self.clientId,
                        deviceInfo: getDeviceInfo(),
                        redirectURI: nil,
                        code: nil,
                        codeVerifier: nil,
                        refreshToken: nil,
                        jwt: nil,
                        accessToken: self.accessToken
                    )
                    if let idToken = oidcTokenResponse.idToken {
                        self.idToken = idToken
                    }
                    handler(.success(()))
                } catch {
                    _ = self._handleInvalidGrantException(error: error)
                    handler(.failure(wrapError(error: error)))
                }
            }
        }

        refreshAccessTokenIfNeeded { _ in
            task()
        }
    }

    public func wechatAuthCallback(code: String, state: String, handler: VoidCompletionHandler? = nil) {
        let handler = handler.map { h in withMainQueueHandler(h) }
        workerQueue.async {
            do {
                try self.apiClient.syncRequestWechatAuthCallback(
                    code: code,
                    state: state
                )
                handler?(.success(()))
            } catch {
                handler?(.failure(wrapError(error: error)))
            }
        }
    }

    @available(iOS 11.3, *)
    public func checkBiometricSupported() throws {
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        let context = LAContext(policy: policy)
        var error: NSError?
        _ = context.canEvaluatePolicy(policy, error: &error)
        if let error = error {
            throw wrapError(error: error)
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
    public func enableBiometric(
        localizedReason: String,
        constraint: BiometricAccessConstraint,
        handler: @escaping VoidCompletionHandler
    ) {
        let handler = withMainQueueHandler(handler)

        let laPolicy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
        let context = LAContext(policy: laPolicy)
        // First we perform a biometric authentication first.
        // But this actually is just a test to ensure biometric authentication works.
        context.evaluatePolicy(
            laPolicy,
            localizedReason: localizedReason
        ) { _, error in
            if let error = error {
                handler(.failure(wrapError(error: error)))
                return
            }

            let biometricSetup = { (accessToken: String) in
                self.workerQueue.async {
                    do {
                        let challenge = try self.apiClient.syncRequestOAuthChallenge(purpose: "biometric_request").token
                        let kid = UUID().uuidString
                        let tag = "com.authgear.keys.biometric.\(kid)"
                        let privateKey = try generatePrivateKey()
                        try addPrivateKey(privateKey: privateKey, tag: tag, constraint: constraint, laContext: context)
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
                        _ = self._handleInvalidGrantException(error: error)
                        handler(.failure(wrapError(error: error)))
                    }
                }
            }

            self.refreshAccessTokenIfNeeded { _ in
                biometricSetup(self.accessToken ?? "")
            }
        }
    }

    @available(iOS 11.3, *)
    public func authenticateBiometric(
        localizedReason: String,
        policy: BiometricLAPolicy,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let laPolicy = policy.laPolicy
        let handler = withMainQueueHandler(handler)
        let context = LAContext(policy: laPolicy)

        context.evaluatePolicy(
            laPolicy,
            localizedReason: localizedReason
        ) { _, error in
            if let error = error {
                handler(.failure(wrapError(error: error)))
                return
            }

            self.workerQueue.async {
                do {
                    guard let kid = try self.storage.getBiometricKeyId(namespace: self.name) else {
                        throw AuthgearError.biometricPrivateKeyNotFound
                    }
                    let challenge = try self.apiClient.syncRequestOAuthChallenge(purpose: "biometric_request").token
                    let tag = "com.authgear.keys.biometric.\(kid)"
                    guard let privateKey = try getPrivateKey(tag: tag, laContext: context) else {
                        // If the constraint was biometryCurrentSet,
                        // then the private key may be deleted by the system
                        // when biometric has been changed by the device owner.
                        // In this case, perform cleanup.
                        try self.disableBiometric()
                        throw AuthgearError.biometricPrivateKeyNotFound
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
                        deviceInfo: getDeviceInfo(),
                        redirectURI: nil,
                        code: nil,
                        codeVerifier: nil,
                        refreshToken: nil,
                        jwt: signedJWT,
                        accessToken: nil
                    )

                    let userInfo = try self.apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken!)
                    let result = self.persistSession(oidcTokenResponse, reason: .authenticated)
                        .map { userInfo }
                    return handler(result)
                } catch {
                    // In case the biometric was removed remotely.
                    if case let AuthgearError.oauthError(oauthError) = error {
                        if oauthError.error == "invalid_grant" && oauthError.errorDescription == "InvalidCredentials" {
                            try? self.disableBiometric()
                        }
                    }
                    handler(.failure(wrapError(error: error)))
                }
            }
        }
    }

    private func _handleInvalidGrantException(error: Error) -> Result<Void, Error> {
        if let error = error as? AuthgearError,
           case let .oauthError(oauthError) = error,
           oauthError.error == "invalid_grant" {
            return self.cleanupSession(force: true, reason: .invalid)
        } else if let error = error as? AuthgearError,
                  case let .serverError(serverError) = error,
                  serverError.reason == "InvalidGrant" {
            return self.cleanupSession(force: true, reason: .invalid)
        }
        return .success(())
    }
}
