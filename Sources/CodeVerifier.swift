import CommonCrypto
import Foundation

struct CodeVerifier {
    static func generateValue() -> String {
        // https://datatracker.ietf.org/doc/html/rfc7636#section-4.1
        // It is RECOMMENDED that the output of
        // a suitable random number generator be used to create a 32-octet
        // sequence.  The octet sequence is then base64url-encoded to produce a
        // 43-octet URL safe string to use as the code verifier.
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)

        let data = Data(buffer)
        return data.base64urlEncodedString()
    }

    static func computeCodeChallenge(_ value: String) -> String {
        let data = value.data(using: .utf8)!
        var buffer = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))

        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &buffer)
        }

        let hash = Data(buffer)

        return hash.base64urlEncodedString()
    }

    let value: String
    let codeChallenge: String

    init() {
        self.value = CodeVerifier.generateValue()
        self.codeChallenge = CodeVerifier.computeCodeChallenge(value)
    }
}
