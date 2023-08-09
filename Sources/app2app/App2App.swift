import Foundation
import UIKit

class App2App {
    typealias ResultUnsubscriber = () -> Void
    typealias ResultHandler = (URL) -> Void
    
    private let namespace: String
    private let apiClient: AuthAPIClient
    private let storage: ContainerStorage
    private let dispatchQueue: DispatchQueue
    
    private var resultHandlerRegistry: Dictionary<String, WeakHandlerRef> = Dictionary()
    private let resultHandlerLock = NSLock()
    
    init(
        namespace: String,
        apiClient: AuthAPIClient,
        storage: ContainerStorage,
        dispatchQueue: DispatchQueue
    ) {
        self.namespace = namespace
        self.apiClient = apiClient
        self.storage = storage
        self.dispatchQueue = dispatchQueue
    }
    
    func requireMinimumApp2AppIOSVersion() throws {
        if #available(iOS 11.3, *) {
            return
        } else {
            throw AuthgearError.runtimeError("App2App authentication requires at least ios 11.3")
        }
    }
    
    @available(iOS 11.3, *)
    private func generatePrivateKey(tag: String) throws -> SecKey {
        var error: Unmanaged<CFError>?
        let query: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag
            ]
        ]
        guard let privateKey = SecKeyCreateRandomKey(query as CFDictionary, &error) else {
            throw AuthgearError.error(error!.takeRetainedValue() as Error)
        }
        return privateKey
    }

    @available(iOS 11.3, *)
    private func removePrivateKey(tag: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag as String: tag,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    @available(iOS 11.3, *)
    private func getPrivateKey(tag: String) throws -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrApplicationTag as String: tag,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        let privateKey = item as! SecKey
        return privateKey
    }
    
    private func openURLInUniversalLink(
        url: URL,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        let options: [UIApplication.OpenExternalURLOptionsKey : Any] = [
            UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: NSNumber(value: true)
        ]
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: options) { success in
                if (success) {
                    handler(.success(()))
                } else {
                    handler(.failure(OAuthError(
                        error: "invalid_client",
                        errorDescription: "failed to open url \(url.absoluteString)",
                        errorUri: nil)))
                }
            }
        }
    }
    
    @available(iOS 11.3, *)
    func generateApp2AppJWT() throws -> String {
        let challenge = try apiClient.syncRequestOAuthChallenge(purpose: "app2app_request").token
        let existingKid = try storage.getApp2AppDeviceKeyId(namespace: namespace)
        let kid = existingKid ?? UUID().uuidString
        let tag = "com.authgear.keys.app2app.\(kid)"
        let existingPrivateKey = try getPrivateKey(tag: tag)
        let privateKey: SecKey
        if let existingPrivateKey = existingPrivateKey {
            privateKey = existingPrivateKey
        } else {
            privateKey = try generatePrivateKey(tag: tag)
            try storage.setApp2AppDeviceKeyId(namespace: namespace, kid: kid)
        }
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        let jwk = try publicKeyToJWK(kid: kid, publicKey: publicKey)
        let header = JWTHeader(typ: .app2app, jwk: jwk, new: true)
        let payload = JWTPayload(challenge: challenge, action: App2AppPayloadAction.setup.rawValue)
        let jwt = JWT(header: header, payload: payload)
        let signedJWT = try jwt.sign(with: JWTSigner(privateKey: privateKey))
        return signedJWT
    }
    
    @available(iOS 11.3, *)
    func startAuthenticateRequest(
        request: App2AppAuthenticateRequest,
        handler: @escaping (Result<Void, Error>) -> Void
    ) throws {
        let url = try request.toURL()
        openURLInUniversalLink(url: url, handler: handler)
    }
    
    @available(iOS 11.3, *)
    func parseApp2AppAuthenticationRequest(url: URL, expectedEndpoint: String) -> App2AppAuthenticateRequest? {
        let parsedRequest = App2AppAuthenticateRequest.parse(url: url)
        if (expectedEndpoint != parsedRequest?.authorizationEndpoint) {
            return nil
        }
        return parsedRequest
    }
    
    @available(iOS 11.3, *)
    func approveApp2AppAuthenticationRequest(
        maybeRefreshToken: String?,
        request: App2AppAuthenticateRequest,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        var resultURL: URL
        do {
            resultURL = try doApproveApp2AppAuthenticationRequest(
                maybeRefreshToken: maybeRefreshToken,
                request: request)
        } catch {
            resultURL = constructErrorURL(
                redirectUri: request.redirectUri,
                defaultError: "unknown_error",
                e: error)
        }
        openURLInUniversalLink(url: resultURL, handler: handler)
    }
    
    @available(iOS 11.3, *)
    func rejectApp2AppAuthenticationRequest(
        request: App2AppAuthenticateRequest,
        reason: Error,
        handler: @escaping (Result<Void, Error>) -> Void
    ) {
        let resultURL = constructErrorURL(
            redirectUri: request.redirectUri,
            defaultError: "unknown_error",
            e: reason)
        openURLInUniversalLink(url: resultURL, handler: handler)
    }
    
    private func constructErrorURL(redirectUri: URL, defaultError: String, e: Error) -> URL {
        var error = defaultError
        var errorDescription: String? = "Unknown error"
        if let localizedErr = e as? LocalizedError {
            errorDescription = localizedErr.errorDescription
        }
        if let oauthErr = e as? OAuthError {
            error = oauthErr.error
            errorDescription = oauthErr.errorDescription
        } else if let serverErr = e as? ServerError {
            error = "server_error"
            errorDescription = serverErr.message
        }
        
        var query = [
            "error": error
        ]
        if let errorDescription = errorDescription {
            query["error_description"] = errorDescription
        }
        var urlcomponents = URLComponents(
            url: redirectUri,
            resolvingAgainstBaseURL: false
        )!
        urlcomponents.percentEncodedQuery = query.encodeAsQuery()
        return urlcomponents.url!
    }
    
    @available(iOS 11.3, *)
    private func doApproveApp2AppAuthenticationRequest(
        maybeRefreshToken: String?,
        request: App2AppAuthenticateRequest
    ) throws -> URL {
        guard let refreshToken = maybeRefreshToken else {
            throw OAuthError(
                error: "invalid_grant",
                errorDescription: "unauthenticated",
                errorUri: nil
            )
        }
        let jwt = try generateApp2AppJWT()
        let oidcTokenResponse = try apiClient.syncRequestOIDCToken(
            grantType: GrantType.app2app,
            clientId: request.clientID,
            deviceInfo: nil,
            redirectURI: request.redirectUri.absoluteString,
            code: nil,
            codeVerifier: nil,
            codeChallenge: request.codeChallenge,
            codeChallengeMethod: Authgear.CodeChallengeMethod,
            refreshToken: refreshToken,
            jwt: nil,
            accessToken: nil,
            xApp2AppDeviceKeyJwt: jwt
        )
        let code = oidcTokenResponse.code ?? ""
        let query: [String: String] = [
            "code": code
        ]
        var urlcomponents = URLComponents(
            url: request.redirectUri,
            resolvingAgainstBaseURL: false
        )!
        urlcomponents.percentEncodedQuery = query.encodeAsQuery()
        return urlcomponents.url!
    }
    
    func listenToApp2AppAuthenticationResult(redirectUri: String, handler: @escaping ResultHandler) -> App2App.ResultUnsubscriber {
        let normalizedRedirectUri = normalizeRedirectUri(redirectUri)
        let handlerContainer = HandlerContainer(fn: handler)
        let weakRef = WeakHandlerRef(handlerContainer)
        dispatchQueue.async {
            self.resultHandlerLock.lock()
            self.resultHandlerRegistry[normalizedRedirectUri] = weakRef
            self.resultHandlerLock.unlock()
        }
        return { () in
            self.dispatchQueue.async {
                self.resultHandlerLock.lock()
                self.resultHandlerRegistry.removeValue(forKey: normalizedRedirectUri)
                self.resultHandlerLock.unlock()
            }
        }
    }
    
    func handleApp2AppAuthenticationResult(url: URL) -> Bool {
        let normalizedRedirectUri = normalizeRedirectUri(url.absoluteString)
        let handleAsync = {
            let fn = self.resultHandlerRegistry[normalizedRedirectUri]?.container?.fn
            if let fn = fn {
                self.dispatchQueue.async {
                    fn(url)
                }
                return true
            }
            return false
        }
        resultHandlerLock.lock()
        let result = handleAsync()
        resultHandlerLock.unlock()
        return result
    }
    
    private func normalizeRedirectUri(_ redirectUri: String) -> String {
        var urlcomponents = URLComponents(string: redirectUri)!
        urlcomponents.percentEncodedQuery = nil
        urlcomponents.fragment = nil
        return urlcomponents.url!.absoluteString
    }
}

private class HandlerContainer {
    let fn: App2App.ResultHandler
    
    init(fn: @escaping App2App.ResultHandler) {
        self.fn = fn
    }
}

private class WeakHandlerRef {
    weak var container: HandlerContainer?
    
    init(_ container: HandlerContainer? = nil) {
        self.container = container
    }
}
