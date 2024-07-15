import Foundation

class DefaultDPoPProvider: DPoPProvider {
    private let namespace: String
    private let sharedStorage: InterAppSharedStorage

    init(namespace: String, sharedStorage: InterAppSharedStorage) {
        self.namespace = namespace
        self.sharedStorage = sharedStorage
    }

    func generateDPoPProof(htm: String, htu: String) throws -> String {
        if #unavailable(iOS 11.3) {
            return ""
        }
        let (kid, privateKey) = try getOrCreateDPoPPrivateKey()
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        let jwk = try publicKeyToJWK(kid: kid, publicKey: publicKey)
        let header = JWTHeader(typ: .dpopjwt, jwk: jwk, includeJWK: true)
        let payload = JWTPayload(
            jti: UUID().uuidString,
            htm: htm,
            htu: htu
        )
        let jwt = JWT(header: header, payload: payload)
        let signedJWT = try jwt.sign(with: JWTSigner(privateKey: privateKey))
        return signedJWT
    }

    func computeJKT() throws -> String {
        if #unavailable(iOS 11.3) {
            return ""
        }
        let (kid, privateKey) = try getOrCreateDPoPPrivateKey()
        let publicKey = SecKeyCopyPublicKey(privateKey)!
        let jwk = try publicKeyToJWK(kid: kid, publicKey: publicKey)
        return try jwk.thumbprint(algorithm: .SHA256)
    }

    @available(iOS 11.3, *)
    private func generatePrivateKey(tag: String) throws -> SecKey {
        var error: Unmanaged<CFError>?
        let attributes: NSDictionary = [
            kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits: 256,
            kSecAttrTokenID: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrApplicationTag: tag
            ]
        ]
        guard let privateKey = SecKeyCreateRandomKey(attributes, &error) else {
            throw AuthgearError.error(error!.takeRetainedValue() as Error)
        }
        return privateKey
    }

    @available(iOS 11.3, *)
    private func getPrivateKey(tag: String) throws -> SecKey? {
        let query: NSDictionary = [
            kSecClass: kSecClassKey,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecAttrApplicationTag: tag,
            kSecReturnRef: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query, &item)

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
    private func getOrCreateDPoPPrivateKey() throws -> (String, SecKey) {
        let existingKid = try sharedStorage.getDPoPKeyId(namespace: namespace)
        if let existingKid = existingKid {
            let tag = getDPoPPrivateKeyTag(kid: existingKid)
            if let privateKey = try? getPrivateKey(tag: tag) {
                return (existingKid, privateKey)
            }
        }
        let kid = UUID().uuidString
        let tag = getDPoPPrivateKeyTag(kid: kid)
        let privateKey = try generatePrivateKey(tag: tag)
        try sharedStorage.setDPoPKeyId(namespace: namespace, kid: kid)
        return (kid, privateKey)
    }

    private func getDPoPPrivateKeyTag(kid: String) -> String {
        "com.authgear.keys.dpop.\(kid)"
    }
}
