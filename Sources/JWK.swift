import Foundation
import Security

struct JWK: Encodable {
    let kid: String
    let kty: String
    let alg: String

    // RSA
    let n: String?
    let e: String?

    // EC
    let x: String?
    let y: String?
    let crv: String?

    init(kid: String, alg: String, n: String, e: String) {
        self.kid = kid
        self.kty = "RSA"
        self.alg = alg
        self.n = n
        self.e = e

        self.x = nil
        self.y = nil
        self.crv = nil
    }

    init(kid: String, alg: String, x: String, y: String, crv: String) {
        self.kid = kid
        self.alg = alg
        self.kty = "EC"
        self.x = x
        self.y = y
        self.crv = crv

        self.n = nil
        self.e = nil
    }
}

enum KeyType {
    case rsa
    case ec

    static func from(_ seckey: SecKey) -> KeyType {
        guard let attributes = SecKeyCopyAttributes(seckey) as? [CFString: Any],
              let keyType = attributes[kSecAttrKeyType] as? String else {
            return .rsa
        }

        if (keyType == (kSecAttrKeyTypeECSECPrimeRandom as String)) {
            return .ec
        }
        return .rsa
    }
}

enum ECCurveType: String {
    case P256 = "P-256"

    var coordinateOctetLength: Int {
        switch self {
        case .P256:
            return 32
        }
    }
}

private func publicKeyToRSAJWK(kid: String, data: Data) -> JWK {
    let n = data.subdata(in: Range(NSRange(location: data.count > 269 ? 9 : 8, length: 256))!)
    let e = data.subdata(in: Range(NSRange(location: data.count - 3, length: 3))!)

    return JWK(
        kid: kid,
        alg: "RS256",
        n: n.base64urlEncodedString(),
        e: e.base64urlEncodedString()
    )
}

private func publicKeyToECJWK(kid: String, data: Data) throws -> JWK {
    // refernce: https://github.com/airsidemobile/JOSESwift/blob/2.4.0/JOSESwift/Sources/CryptoImplementation/DataECPublicKey.swift

    var publicKeyBytes = [UInt8](data)

    guard publicKeyBytes.removeFirst() == 0x04 else {
        throw AuthgearError.runtimeError("unexpected ec public key format")
    }

    let crv = ECCurveType.P256
    let coordinateOctetLength = crv.coordinateOctetLength

    let xBytes = publicKeyBytes[0..<coordinateOctetLength]
    let yBytes = publicKeyBytes[coordinateOctetLength..<coordinateOctetLength * 2]
    let xData = Data(xBytes)
    let yData = Data(yBytes)

    return JWK(
        kid: kid,
        alg: "ES256",
        x: xData.base64urlEncodedString(),
        y: yData.base64urlEncodedString(),
        crv: crv.rawValue
    )
}

func publicKeyToJWK(kid: String, publicKey: SecKey) throws -> JWK {
    var error: Unmanaged<CFError>?
    guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) else {
        throw AuthgearError.error(error!.takeRetainedValue() as Error)
    }
    let data = keyData as Data

    switch KeyType.from(publicKey) {
    case .rsa:
        return publicKeyToRSAJWK(kid: kid, data: data)
    default:
        return try publicKeyToECJWK(kid: kid, data: data)
    }
}

struct JWKStore {
    func loadKey(keyId: String, tag: String) throws -> JWK? {
        if let privateKey = try loadPrivateKey(tag: tag) {
            if let publicKey = SecKeyCopyPublicKey(privateKey) {
                return try publicKeyToJWK(kid: keyId, publicKey: publicKey)
            }
            throw AuthgearError.publicKeyNotFound
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
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
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
            return try publicKeyToJWK(kid: keyId, publicKey: publicKeySec!)
        default:
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
