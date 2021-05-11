import CommonCrypto
import Foundation

enum JWTHeaderType: String, Encodable {
    case anonymous = "vnd.authgear.anonymous-request"
    case biometric = "vnd.authgear.biometric-request"
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
}

struct JWTSigner {
    private let privateKey: SecKey

    init(privateKey: SecKey) {
        self.privateKey = privateKey
    }

    func sign(header: String, payload: String) throws -> String {
        let data = "\(header).\(payload)".data(using: .utf8)!
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        var error: Unmanaged<CFError>?

        guard let signedData = SecKeyCreateSignature(privateKey, .rsaSignatureDigestPKCS1v15SHA256, Data(buffer) as CFData, &error) else {
            throw AuthgearError.error(error!.takeRetainedValue() as Error)
        }

        return (signedData as Data).base64urlEncodedString()
    }
}
