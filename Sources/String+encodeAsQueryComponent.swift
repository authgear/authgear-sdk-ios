import Foundation

private extension CharacterSet {
    static var queryComponentAllowed: CharacterSet {
        // See https://url.spec.whatwg.org/#component-percent-encode-set
        CharacterSet.urlUserAllowed.subtracting([
            // userinfo percent-encode set
            "/", ":", ";", "=", "@", "[", "\\", "]", "^", "|",
            // component percent-encode set
            "$", "%", "&", "+", ","
        ])
    }
}

extension String {
    func encodeAsQueryComponent() -> String? {
        self.addingPercentEncoding(
            withAllowedCharacters: CharacterSet.queryComponentAllowed)
    }
}
