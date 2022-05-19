import CommonCrypto
import Foundation

struct CodeVerifier {
    static func generateValue() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        return buffer
            .map { $0 & 0xFF }
            .map { String(format: "%02X", $0) }
            .joined()
    }

    static func computeCodeChallenge(_ value: String) -> String {
        let data = value.data(using: .utf8)!
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        let hash = Data(buffer.map { $0 & 0xFF })

        return hash.base64urlEncodedString()
    }

    let value: String
    let codeChallenge: String

    init() {
        self.value = CodeVerifier.generateValue()
        self.codeChallenge = CodeVerifier.computeCodeChallenge(value)
    }
}
