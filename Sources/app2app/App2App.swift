import Foundation
import UIKit

class App2App {
    private let namespace: String
    private let apiClient: AuthAPIClient
    private let storage: ContainerStorage
    
    internal init(
        namespace: String,
        apiClient: AuthAPIClient,
        storage: ContainerStorage
    ) {
        self.namespace = namespace
        self.apiClient = apiClient
        self.storage = storage
    }
    
    internal func requireMinimumApp2AppIOSVersion() throws {
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
    
    @available(iOS 11.3, *)
    internal func generateApp2AppJWT() throws -> String {
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
    internal func startAuthenticateRequest(
        request: App2AppAuthenticateRequest,
        handler: @escaping (Result<Void, Error>) -> Void
    ) throws {
        let url = try request.toURL()
        let options: [UIApplication.OpenExternalURLOptionsKey : Any] = [
            UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: NSNumber(value: true)
        ]
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
    
    @available(iOS 11.3, *)
    internal func parseApp2AppAuthenticationRequest(url: URL) -> App2AppAuthenticateRequest? {
        return App2AppAuthenticateRequest.parse(url: url)
    }
}
