import CommonCrypto
import Foundation

enum JWTHeaderType: String, Encodable {
    case anonymous = "vnd.authgear.anonymous-request"
    case biometric = "vnd.authgear.biometric-request"
    case app2app = "vnd.authgear.app2app-request"
}

struct JWTHeader: Encodable {
    let typ: JWTHeaderType
    let kid: String
    let alg: String
    let jwk: JWK?

    init(typ: JWTHeaderType, jwk: JWK, new: Bool) {
        self.typ = typ
        kid = jwk.kid
        alg = jwk.alg
        if new {
            self.jwk = jwk
        } else {
            self.jwk = nil
        }
    }

    func encode() throws -> String {
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(self)
        return data.base64urlEncodedString()
    }
}

enum AnonymousPayloadAction: String, Encodable {
    case auth
    case promote
}

enum BiometricPayloadAction: String, Encodable {
    case setup
    case authenticate
}

enum App2AppPayloadAction: String, Encodable {
    case setup
}

struct JWTPayload: Encodable {
    let iat: Int
    let exp: Int
    let challenge: String
    let action: String
    let deviceInfo: DeviceInfoRoot

    enum CodingKeys: String, CodingKey {
        case iat
        case exp
        case challenge
        case action
        case deviceInfo = "device_info"
    }

    init(challenge: String, action: String) {
        let now = Int(Date().timeIntervalSince1970)
        iat = now
        exp = now + 60
        self.challenge = challenge
        self.action = action
        self.deviceInfo = getDeviceInfo()
    }

    func encode() throws -> String {
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(self)
        return data.base64urlEncodedString()
    }
}

struct JWT {
    let header: JWTHeader
    let payload: JWTPayload

    func sign(with signer: JWTSigner) throws -> String {
        let header = try self.header.encode()
        let payload = try self.payload.encode()
        let signature = try signer.sign(header: header, payload: payload)
        return "\(header).\(payload).\(signature)"
    }

    static func decode(jwt: String) throws -> [String: Any] {
        let parts = jwt.components(separatedBy: ".")
        if parts.count != 3 {
            throw AuthgearError.invalidJWT(jwt)
        }
        let payloadStr = parts[1]
        let base64 = base64urlToBase64(base64url: payloadStr)
        guard let data = Data(base64Encoded: base64) else {
            throw AuthgearError.invalidJWT(jwt)
        }
        let anything = try JSONSerialization.jsonObject(with: data, options: [])
        guard let payload = anything as? [String: Any] else {
            throw AuthgearError.invalidJWT(jwt)
        }
        return payload
    }
}

struct JWTSigner {
    private let privateKey: SecKey

    init(privateKey: SecKey) {
        self.privateKey = privateKey
    }

    private func createRSASignature(input: Data) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            input as CFData,
            &error
        ) else {
            throw AuthgearError.error(error!.takeRetainedValue() as Error)
        }
        return signature as Data
    }

    private func createECSignature(input: Data) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            input as CFData,
            &error
        ) else {
            throw AuthgearError.error(error!.takeRetainedValue() as Error)
        }

        // Convert the signature to correct format
        // See https://github.com/airsidemobile/JOSESwift/blob/2.4.0/JOSESwift/Sources/CryptoImplementation/EC.swift#L208
        let crv = ECCurveType.P256
        let ecSignatureTLV = [UInt8](signature as Data)
        let ecSignature = try ecSignatureTLV.read(.sequence)
        let varlenR = try Data(ecSignature.read(.integer))
        let varlenS = try Data(ecSignature.skip(.integer).read(.integer))
        let fixlenR = Asn1IntegerConversion.toRaw(varlenR, of: crv.coordinateOctetLength)
        let fixlenS = Asn1IntegerConversion.toRaw(varlenS, of: crv.coordinateOctetLength)

        let fixedSignature = (fixlenR + fixlenS)
        return fixedSignature
    }

    func sign(header: String, payload: String) throws -> String {
        let data = "\(header).\(payload)".data(using: .utf8)!

        let signature: Data
        switch KeyType.from(privateKey) {
        case .rsa:
            signature = try createRSASignature(input: data)
        default:
            signature = try createECSignature(input: data)
        }

        return signature.base64urlEncodedString()
    }
}
