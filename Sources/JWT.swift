//
//  JWT.swift
//  Authgear-iOS
//
//  Created by Peter Cheng on 7/9/2020.
//

import Foundation
import CommonCrypto

internal protocol JWTHeader: Encodable {
    func encode() throws -> String
}

extension JWTHeader {
    func encode() throws -> String {
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(self)
        return data.base64urlEncodedString()
    }
}

internal protocol JWTPayload: Encodable {
    func encode() throws -> String
}

extension JWTPayload {
    func encode() throws -> String {
        let jsonEncoder = JSONEncoder()
        let data = try jsonEncoder.encode(self)
        return data.base64urlEncodedString()
    }
}

internal struct JWTSigner {

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

        guard let signedData = SecKeyCreateSignature(self.privateKey, .rsaSignatureDigestPKCS1v15SHA256, Data(buffer) as CFData, &error) else {
            throw JWKError.keyError(JWKError.keyError(error!
                .takeRetainedValue() as Error))
        }

        return (signedData as Data).base64urlEncodedString()
    }
}

internal struct JWT<Header: JWTHeader, Payload: JWTPayload> {
    let header: Header
    let payload: Payload

    func sign(with signer: JWTSigner) throws -> String {
        let header = try self.header.encode()
        let payload = try self.payload.encode()
        let signature = try signer.sign(header: header, payload: payload)
        return "\(header).\(payload).\(signature)"
    }
}

typealias AnonymousJWT = JWT<AnonymousJWTHeader,AnonymousJWYPayload>

internal struct AnonymousJWTHeader: JWTHeader {
    let typ = "vnd.authgear.anonymous-request"
    let kid: String
    let alg: String
    let jwk: JWK?

    init(jwk: JWK, new: Bool = true) {
        self.kid = jwk.kid
        self.alg = jwk.alg

        if new {
            self.jwk = jwk
        } else {
            self.jwk = nil
        }
    }
}

internal struct AnonymousJWYPayload: JWTPayload {
    enum Action: String, Encodable {
        case auth
        case promote
    }
    let iat: Int
    let exp: Int
    let challenge: String
    let action: Action

    init(challenge: String, action: Action) {
        let now = Int(Date().timeIntervalSince1970)
        self.iat = now
        self.exp = now + 60
        self.challenge = challenge
        self.action = action
    }
}
