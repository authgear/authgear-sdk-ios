import AuthenticationServices
import Foundation
import LocalAuthentication
import SafariServices
import Security
import WebKit

public typealias UserInfoCompletionHandler = (Result<UserInfo, Error>) -> Void
public typealias VoidCompletionHandler = (Result<Void, Error>) -> Void
public typealias URLCompletionHandler = (Result<URL, Error>) -> Void

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
    let xState: String?
    let prompt: [PromptOption]?
    let loginHint: String?
    let uiLocales: [String]?
    let colorScheme: ColorScheme?
    let wechatRedirectURI: String?
    let page: AuthenticationPage?

    var request: OIDCAuthenticationRequest {
        OIDCAuthenticationRequest(
            redirectURI: self.redirectURI,
            responseType: "code",
            scope: ["openid", "offline_access", "https://authgear.com/scopes/full-access"],
            isSSOEnabled: isSSOEnabled,
            state: self.state,
            xState: self.xState,
            prompt: self.prompt,
            loginHint: self.loginHint,
            uiLocales: self.uiLocales,
            colorScheme: self.colorScheme,
            idTokenHint: nil,
            maxAge: nil,
            wechatRedirectURI: self.wechatRedirectURI,
            page: self.page
        )
    }
}

struct AuthenticationRequest {
    let url: URL
    let redirectURI: String
    let verifier: CodeVerifier
}

struct ReauthenticateOptions {
    let redirectURI: String
    let isSSOEnabled: Bool
    let state: String?
    let xState: String?
    let uiLocales: [String]?
    let colorScheme: ColorScheme?
    let wechatRedirectURI: String?
    let maxAge: Int?

    func toRequest(idTokenHint: String) -> OIDCAuthenticationRequest {
        OIDCAuthenticationRequest(
            redirectURI: self.redirectURI,
            responseType: "code",
            scope: ["openid", "https://authgear.com/scopes/full-access"],
            isSSOEnabled: isSSOEnabled,
            state: self.state,
            xState: self.xState,
            prompt: nil,
            loginHint: nil,
            uiLocales: self.uiLocales,
            colorScheme: self.colorScheme,
            idTokenHint: idTokenHint,
            maxAge: self.maxAge ?? 0,
            wechatRedirectURI: self.wechatRedirectURI,
            page: nil
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

    static let CodeChallengeMethod = "S256"

    let name: String
    let clientId: String
    let apiClient: AuthAPIClient
    let storage: ContainerStorage
    var tokenStorage: TokenStorage
    public let isSSOEnabled: Bool
    private var shareCookiesWithDeviceBrowser: Bool {
        get {
            return self.isSSOEnabled
        }
    }

    var uiImplementation: UIImplementation

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

    private let accessTokenRefreshLock = NSLock()
    private let accessTokenRefreshQueue: DispatchQueue

    private let app2AppOptions: App2AppOptions
    private let app2app: App2App

    private var currentWechatRedirectURI: String?

    public private(set) var sessionState: SessionState = .unknown

    public weak var delegate: AuthgearDelegate?

    public init(
        clientId: String,
        endpoint: String,
        tokenStorage: TokenStorage = PersistentTokenStorage(),
        uiImplementation: UIImplementation = ASWebAuthenticationSessionUIImplementation(),
        isSSOEnabled: Bool = false,
        name: String? = nil,
        app2AppOptions: App2AppOptions = App2AppOptions(
            isEnabled: false,
            authorizationEndpoint: nil
        )
    ) {
        self.clientId = clientId
        self.name = name ?? "default"
        self.tokenStorage = tokenStorage
        self.uiImplementation = uiImplementation
        self.storage = PersistentContainerStorage()
        self.isSSOEnabled = isSSOEnabled
        self.apiClient = DefaultAuthAPIClient(endpoint: URL(string: endpoint)!)
        self.workerQueue = DispatchQueue(label: "authgear:\(self.name)", qos: .utility)
        self.accessTokenRefreshQueue = DispatchQueue(label: "authgear:\(self.name)", qos: .utility)
        self.app2AppOptions = app2AppOptions

        self.app2app = App2App(
            namespace: self.name,
            apiClient: self.apiClient,
            storage: self.storage,
            dispatchQueue: self.workerQueue
        )
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

    func buildAuthorizationURL(request: OIDCAuthenticationRequest, verifier: CodeVerifier?) throws -> URL {
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

            DispatchQueue.main.async {
                self.registerCurrentWechatRedirectURI(uri: options.wechatRedirectURI)
                self.uiImplementation.openAuthorizationURL(url: url, redirectURI: URL(string: request.redirectURI)!, shareCookiesWithDeviceBrowser: self.shareCookiesWithDeviceBrowser) { result in
                    self.unregisterCurrentWechatRedirectURI()
                    switch result {
                    case let .success(url):
                        self.workerQueue.async {
                            self.finishReauthentication(url: url, verifier: verifier, handler: handler)
                        }
                    case let .failure(error):
                        return handler(.failure(wrapError(error: error)))
                    }
                }
            }
        } catch {
            handler(.failure(wrapError(error: error)))
        }
    }

    func createAuthenticateRequest(_ options: AuthenticateOptions) -> Result<AuthenticationRequest, Error> {
        let verifier = CodeVerifier()
        let request = options.request
        let url = Result { try self.buildAuthorizationURL(request: request, verifier: verifier) }

        return url.map { url in
            AuthenticationRequest(url: url, redirectURI: request.redirectURI, verifier: verifier)
        }
    }

    private func authenticateWithASWebAuthenticationSession(
        _ options: AuthenticateOptions,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let request = self.createAuthenticateRequest(options)

        DispatchQueue.main.async {
            switch request {
            case let .success(request):
                self.registerCurrentWechatRedirectURI(uri: options.wechatRedirectURI)
                self.uiImplementation.openAuthorizationURL(url: request.url, redirectURI: URL(string: request.redirectURI)!, shareCookiesWithDeviceBrowser: self.shareCookiesWithDeviceBrowser) { result in
                    self.unregisterCurrentWechatRedirectURI()
                    switch result {
                    case let .success(url):
                        self.workerQueue.async {
                            self.finishAuthentication(url: url, verifier: request.verifier, handler: handler)
                        }
                    case let .failure(error):
                        return handler(.failure(wrapError(error: error)))
                    }
                }
            case let .failure(error):
                handler(.failure(wrapError(error: error)))
            }
        }
    }

    func finishAuthentication(
        url: URL,
        verifier: CodeVerifier,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let params = urlComponents.queryParams

        if let errorParams = params["error"] {
            if errorParams == "cancel" {
                return handler(
                    .failure(AuthgearError.cancel)
                )
            }
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
            var xApp2AppDeviceKeyJwt: String?
            if (app2AppOptions.isEnabled) {
                if #available(iOS 11.3, *) {
                    xApp2AppDeviceKeyJwt = try app2app.generateApp2AppJWT(forceNew: true)
                } else {
                    try app2app.requireMinimumApp2AppIOSVersion()
                }
            }
            let oidcTokenResponse = try apiClient.syncRequestOIDCToken(
                grantType: GrantType.authorizationCode,
                clientId: clientId,
                deviceInfo: getDeviceInfo(),
                redirectURI: redirectURI,
                code: code,
                codeVerifier: verifier.value,
                codeChallenge: nil,
                codeChallengeMethod: nil,
                refreshToken: nil,
                jwt: nil,
                accessToken: nil,
                xApp2AppDeviceKeyJwt: xApp2AppDeviceKeyJwt
            )

            let userInfo = try apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken!)

            persistSession(oidcTokenResponse, reason: .authenticated) { result in
                handler(result.flatMap {
                    Result { () in
                        if #available(iOS 11.3, *) {
                            try self.disableBiometric()
                        }
                    }
                }
                .map { userInfo })
            }
        } catch {
            return handler(.failure(wrapError(error: error)))
        }
    }

    func finishReauthentication(
        url: URL,
        verifier: CodeVerifier,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        let params = urlComponents.queryParams

        if let errorParams = params["error"] {
            if errorParams == "cancel" {
                return handler(
                    .failure(AuthgearError.cancel)
                )
            }
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
            var xApp2AppDeviceKeyJwt: String?
            if (app2AppOptions.isEnabled) {
                if #available(iOS 11.3, *) {
                    xApp2AppDeviceKeyJwt = try app2app.generateApp2AppJWT(forceNew: false)
                } else {
                    try app2app.requireMinimumApp2AppIOSVersion()
                }
            }
            let oidcTokenResponse = try apiClient.syncRequestOIDCToken(
                grantType: GrantType.authorizationCode,
                clientId: clientId,
                deviceInfo: getDeviceInfo(),
                redirectURI: redirectURI,
                code: code,
                codeVerifier: verifier.value,
                codeChallenge: nil,
                codeChallengeMethod: nil,
                refreshToken: nil,
                jwt: nil,
                accessToken: nil,
                xApp2AppDeviceKeyJwt: xApp2AppDeviceKeyJwt
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

    private func persistSession(_ oidcTokenResponse: OIDCTokenResponse, reason: SessionStateChangeReason, handler: @escaping VoidCompletionHandler) {
        if let refreshToken = oidcTokenResponse.refreshToken {
            let result = Result { try self.tokenStorage.setRefreshToken(namespace: self.name, token: refreshToken) }
            guard case .success = result else {
                handler(result)
                return
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
            handler(.success(()))
        }
    }

    private func cleanupSession(force: Bool, reason: SessionStateChangeReason, handler: @escaping VoidCompletionHandler) {
        if case let .failure(error) = Result(catching: { try tokenStorage.delRefreshToken(namespace: name) }) {
            if !force {
                return handler(.failure(wrapError(error: error)))
            }
        }
        if case let .failure(error) = Result(catching: { try storage.delAnonymousKeyId(namespace: name) }) {
            if !force {
                return handler(.failure(wrapError(error: error)))
            }
        }

        DispatchQueue.main.async {
            self.accessToken = nil
            self.refreshToken = nil
            self.idToken = nil
            self.expireAt = nil
            self.setSessionState(.noSession, reason: reason)
            handler(.success(()))
        }
    }

    private func withMainQueueHandler<ResultType, ErrorType: Error>(
        _ handler: @escaping (Result<ResultType, ErrorType>) -> Void
    ) -> ((Result<ResultType, ErrorType>) -> Void) {
        { result in
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
        xState: String? = nil,
        prompt: [PromptOption]? = nil,
        loginHint: String? = nil,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        page: AuthenticationPage? = nil,
        handler: @escaping UserInfoCompletionHandler
    ) {
        self.authenticate(AuthenticateOptions(
            redirectURI: redirectURI,
            isSSOEnabled: self.isSSOEnabled,
            state: state,
            xState: xState,
            prompt: prompt,
            loginHint: loginHint,
            uiLocales: uiLocales,
            colorScheme: colorScheme,
            wechatRedirectURI: wechatRedirectURI,
            page: page
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
        xState: String? = nil,
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
            xState: xState,
            uiLocales: uiLocales,
            colorScheme: colorScheme,
            wechatRedirectURI: wechatRedirectURI,
            maxAge: maxAge
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
                    codeChallenge: nil,
                    codeChallengeMethod: nil,
                    refreshToken: nil,
                    jwt: signedJWT,
                    accessToken: nil,
                    xApp2AppDeviceKeyJwt: nil
                )

                let userInfo = try self.apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken!)

                self.persistSession(oidcTokenResponse, reason: .authenticated) { result in
                    handler(result.flatMap {
                        Result { () in
                            try self.storage.setAnonymousKeyId(namespace: self.name, kid: keyId)
                            if #available(iOS 11.3, *) {
                                try self.disableBiometric()
                            }
                        }
                    }
                    .map { userInfo })
                }
            } catch {
                handler(.failure(wrapError(error: error)))
            }
        }
    }

    public func promoteAnonymousUser(
        redirectURI: String,
        state: String? = nil,
        xState: String? = nil,
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
                        xState: xState,
                        prompt: [.login],
                        loginHint: loginHint,
                        uiLocales: uiLocales,
                        colorScheme: colorScheme,
                        wechatRedirectURI: wechatRedirectURI,
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
                return self.cleanupSession(force: force, reason: .logout, handler: handler)

            } catch {
                if force {
                    return self.cleanupSession(force: true, reason: .logout, handler: handler)
                }
                return handler(.failure(wrapError(error: error)))
            }
        }
    }

    func generateURL(
        redirectURI: String,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        wechatRedirectURI: String? = nil,
        handler: URLCompletionHandler?
    ) {
        let handler = handler.map { h in self.withMainQueueHandler(h) }

        self.workerQueue.async {
            do {
                guard let refreshToken = try self.tokenStorage.getRefreshToken(namespace: self.name) else {
                    handler?(.failure(AuthgearError.unauthenticatedUser))
                    return
                }

                var token = ""
                do {
                    token = try self.apiClient.syncRequestAppSessionToken(refreshToken: refreshToken).appSessionToken
                } catch {
                    self._handleInvalidGrantException(error: error)
                    handler?(.failure(wrapError(error: error)))
                    return
                }

                let loginHint = "https://authgear.com/login_hint?type=app_session_token&app_session_token=\(token.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)"

                let endpoint = try self.buildAuthorizationURL(request: OIDCAuthenticationRequest(
                    redirectURI: redirectURI,
                    responseType: "none",
                    scope: ["openid", "offline_access", "https://authgear.com/scopes/full-access"],
                    isSSOEnabled: self.isSSOEnabled,
                    state: nil,
                    xState: nil,
                    prompt: [.none],
                    loginHint: loginHint,
                    uiLocales: uiLocales,
                    colorScheme: colorScheme,
                    idTokenHint: nil,
                    maxAge: nil,
                    wechatRedirectURI: wechatRedirectURI,
                    page: nil
                ), verifier: nil)

                handler?(.success(endpoint))
            } catch {
                handler?(.failure(wrapError(error: error)))
            }
        }
    }

    func generateAuthgearURL(
        path: String,
        uiLocales: [String]? = nil,
        colorScheme: ColorScheme? = nil,
        handler: URLCompletionHandler?
    ) {
        let handler = handler.map { h in self.withMainQueueHandler(h) }
        self.workerQueue.async {
            self.apiClient.makeAuthgearURL(path: path) { result in
                switch result {
                case let .failure(err):
                    handler?(.failure(err))
                case let .success(url):
                    var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)!
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
                    let redirectURI = urlComponents.url!
                    self.generateURL(redirectURI: redirectURI.absoluteString) { generatedResult in
                        switch generatedResult {
                        case let .failure(err):
                            handler?(.failure(err))
                        case let .success(url):
                            handler?(.success(url))
                        }
                    }
                }
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

        self.generateAuthgearURL(
            path: path,
            uiLocales: uiLocales,
            colorScheme: colorScheme
        ) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .failure(err):
                handler?(.failure(err))

            case let .success(endpoint):
                // For opening setting page, sdk will not know when user end
                // the setting page.
                // So we cannot unregister the wechat uri in this case
                // It is fine to not unresgister it, as everytime we open a
                // new authorize section (authorize or setting page)
                // registerCurrentWeChatRedirectURI will be called and overwrite
                // previous registered wechatRedirectURI
                self.registerCurrentWechatRedirectURI(uri: wechatRedirectURI)

                self.uiImplementation.openAuthorizationURL(
                    url: endpoint,
                    // Opening an arbitrary URL does not have a clear goal.
                    // So here we pass a placeholder redirect uri.
                    redirectURI: URL(string: "nocallback://host/path")!,
                    // prefersEphemeralWebBrowserSession is true so that
                    // the alert dialog is never prompted and
                    // the app session token cookie is forgotten when the webview is closed.
                    shareCookiesWithDeviceBrowser: true
                ) { result in
                    self.unregisterCurrentWechatRedirectURI()
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
                    self.cleanupSession(force: true, reason: .noToken) { result in
                        handler?(result)
                    }
                    return
                }

                let oidcTokenResponse = try self.apiClient.syncRequestOIDCToken(
                    grantType: GrantType.refreshToken,
                    clientId: self.clientId,
                    deviceInfo: getDeviceInfo(),
                    redirectURI: nil,
                    code: nil,
                    codeVerifier: nil,
                    codeChallenge: nil,
                    codeChallengeMethod: nil,
                    refreshToken: refreshToken,
                    jwt: nil,
                    accessToken: nil,
                    xApp2AppDeviceKeyJwt: nil
                )

                self.persistSession(oidcTokenResponse, reason: .foundToken) { result in handler?(result) }
            } catch {
                if let error = error as? AuthgearError,
                   case let .oauthError(oauthError) = error,
                   oauthError.error == "invalid_grant" {
                    self._handleInvalidGrantException(error: error, handler: handler)
                    return
                }
                handler?(.failure(wrapError(error: error)))
            }
        }
    }

    public func refreshAccessTokenIfNeeded(
        handler: @escaping VoidCompletionHandler
    ) {
        accessTokenRefreshQueue.async {
            self.accessTokenRefreshLock.lock()
            func complete(_ result: Result<Void, Error>) {
                self.accessTokenRefreshLock.unlock()
                handler(result)
            }
            if self.shouldRefreshAccessToken() {
                self.refreshAccessToken { result in
                    complete(result)
                }
            } else {
                complete(.success(()))
            }
        }
    }

    public func clearSessionState(
        handler: @escaping VoidCompletionHandler
    ) {
        self.cleanupSession(force: true, reason: .clear, handler: handler)
    }

    public func fetchUserInfo(handler: @escaping UserInfoCompletionHandler) {
        let handler = withMainQueueHandler(handler)
        let fetchUserInfo = { (accessToken: String) in
            self.workerQueue.async {
                let result = Result { try self.apiClient.syncRequestOIDCUserInfo(accessToken: accessToken) }
                if case let .failure(error) = result {
                    self._handleInvalidGrantException(error: error)
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
                        codeChallenge: nil,
                        codeChallengeMethod: nil,
                        refreshToken: nil,
                        jwt: nil,
                        accessToken: self.accessToken,
                        xApp2AppDeviceKeyJwt: nil
                    )
                    if let idToken = oidcTokenResponse.idToken {
                        self.idToken = idToken
                    }
                    handler(.success(()))
                } catch {
                    self._handleInvalidGrantException(error: error)
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
                        self._handleInvalidGrantException(error: error)
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
                        codeChallenge: nil,
                        codeChallengeMethod: nil,
                        refreshToken: nil,
                        jwt: signedJWT,
                        accessToken: nil,
                        xApp2AppDeviceKeyJwt: nil
                    )

                    let userInfo = try self.apiClient.syncRequestOIDCUserInfo(accessToken: oidcTokenResponse.accessToken!)
                    self.persistSession(oidcTokenResponse, reason: .authenticated) { result in
                        handler(result.map { userInfo })
                    }
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

    @available(iOS 11.3, *)
    public func startApp2AppAuthentication(
        options: App2AppAuthenticateOptions,
        handler: @escaping UserInfoCompletionHandler
    ) {
        let handler = withMainQueueHandler(handler)
        let verifier = CodeVerifier()
        let request = options.toRequest(clientID: self.clientId, codeVerifier: verifier)
        self.workerQueue.async {
            do {
                try self.app2app.startAuthenticateRequest(
                    request: request) { success in
                        do {
                            // If failed to start, fail immediately
                            try success.get()
                        } catch {
                            handler(.failure(wrapError(error: error)))
                        }
                        var unsubscribe: (() -> Void)?
                        unsubscribe = self.app2app.listenToApp2AppAuthenticationResult(
                            redirectUri: request.redirectUri.absoluteString
                        ) { [weak self] resultURL in
                            unsubscribe?()
                            guard let this = self else {
                                return
                            }
                            this.finishAuthentication(
                                url: resultURL,
                                verifier: verifier,
                                handler: handler
                            )
                        }
                    }
            } catch {
                handler(.failure(wrapError(error: error)))
            }
        }
    }

    @available(iOS 11.3, *)
    public func parseApp2AppAuthenticationRequest(userActivity: NSUserActivity) -> App2AppAuthenticateRequest? {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else {
            return nil
        }
        guard let incomingURL = userActivity.webpageURL,
              let authorizationEndpoint = app2AppOptions.authorizationEndpoint
        else {
            return nil
        }
        return app2app.parseApp2AppAuthenticationRequest(
            url: incomingURL,
            expectedEndpoint: authorizationEndpoint
        )
    }

    @available(iOS 11.3, *)
    public func approveApp2AppAuthenticationRequest(
        request: App2AppAuthenticateRequest,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        let handler = withMainQueueHandler(handler)
        self.workerQueue.async {
            self.app2app.approveApp2AppAuthenticationRequest(
                maybeRefreshToken: self.refreshToken,
                request: request,
                handler: handler
            )
        }
    }

    @available(iOS 11.3, *)
    public func rejectApp2AppAuthenticationRequest(
        request: App2AppAuthenticateRequest,
        reason: Error,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        let handler = withMainQueueHandler(handler)
        self.workerQueue.async {
            self.app2app.rejectApp2AppAuthenticationRequest(
                request: request,
                reason: reason,
                handler: handler
            )
        }
    }

    @available(iOS 11.3, *)
    public func handleApp2AppAuthenticationResult(
        userActivity: NSUserActivity
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb else {
            return false
        }
        guard let incomingURL = userActivity.webpageURL else {
            return false
        }
        return app2app.handleApp2AppAuthenticationResult(url: incomingURL)
    }

    private func _handleInvalidGrantException(error: Error, handler: VoidCompletionHandler? = nil) {
        if let error = error as? AuthgearError,
           case let .oauthError(oauthError) = error,
           oauthError.error == "invalid_grant" {
            return self.cleanupSession(force: true, reason: .invalid) { result in handler?(result) }
        } else if let error = error as? AuthgearError,
                  case let .serverError(serverError) = error,
                  serverError.reason == "InvalidGrant" {
            return self.cleanupSession(force: true, reason: .invalid) { result in handler?(result) }
        }
        handler?(.success(()))
    }
}
