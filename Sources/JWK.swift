import Foundation
import Security

enum JWKError: Error {
    case publicKeyNotFound
    case unknownError(OSStatus)
    case keyError(Error)
}

struct JWK: Encodable {
    let kid: String
    let alg: String = "RS256"
    let kty: String = "RSA"
    let n: String
    let e: String
}

struct JWKStore {
    func loadKey(keyId: String, tag: String) throws -> JWK? {
        if let privateKey = try loadPrivateKey(tag: tag) {
            if let publicKey = SecKeyCopyPublicKey(privateKey) {
                return try publicKeyToJWK(keyId: keyId, publicKey: publicKey)
            }
            throw JWKError.publicKeyNotFound
        } else {
            return nil
        }
    }

    func loadPrivateKey(tag: String) throws -> SecKey? {
        let query = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 2048,
            kSecAttrIsPermanent as String: kCFBooleanTrue as Any,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!,
            kSecReturnRef as String: kCFBooleanTrue as Any
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            let privateKey = item as! SecKey
            return privateKey
        case errSecItemNotFound:
            return nil
        default:
            throw JWKError.unknownError(status)
        }
    }

    private func publicKeyToJWK(keyId: String, publicKey: SecKey) throws -> JWK {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
            throw JWKError.keyError(error!.takeRetainedValue() as Error)
        }
        let data = keyData as Data

        let n = data.subdata(in: Range(NSRange(location: data.count > 269 ? 9 : 8, length: 256))!)
        let e = data.subdata(in: Range(NSRange(location: data.count - 3, length: 3))!)

        return JWK(
            kid: keyId,
            n: n.base64urlEncodedString(),
            e: e.base64urlEncodedString()
        )
    }

    func generateKey(keyId: String, tag: String) throws -> JWK {
        var publicKeySec, privateKeySec: SecKey?
        let keyattribute = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 2048,
            kSecAttrIsPermanent as String: kCFBooleanTrue as Any,
            kSecAttrApplicationTag as String: tag.data(using: .utf8)!
        ] as CFDictionary

        let status = SecKeyGeneratePair(keyattribute, &publicKeySec, &privateKeySec)

        switch status {
        case errSecSuccess:
            return try publicKeyToJWK(keyId: keyId, publicKey: publicKeySec!)
        default:
            throw JWKError.unknownError(status)
        }
    }
}
