//
//  PKCE.swift
//  Authgear-iOS
//
//  Created by Peter Cheng on 26/8/2020.
//

import Foundation
import CommonCrypto

internal struct CodeVerifier {

    internal let value: String = {
        var buffer = [UInt8](repeating: 0, count: 32)
        let status = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        return buffer
            .map { $0 & 0xff }
            .map { String(format: "%02X", $0) }
            .joined()
    }()

    func computeCodeChallenge() -> String {
        let data = value.data(using: .utf8)!
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        let hash = Data(buffer.map { $0 & 0xff })

        return hash.base64urlEncodedString()
    }
}
