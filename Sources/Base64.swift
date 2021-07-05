import Foundation

func base64urlToBase64(base64url: String) -> String {
    var base64 = base64url
        .replacingOccurrences(of: "-", with: "+")
        .replacingOccurrences(of: "_", with: "/")
    if base64.count % 4 != 0 {
        base64.append(String(repeating: "=", count: 4 - base64.count % 4))
    }
    return base64
}

extension Data {
    func base64urlEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
