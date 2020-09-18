import Foundation

extension URLComponents {
    var queryParams: [String: String] {
        get {
            if let queryItems = self.queryItems {
                return queryItems.reduce([:]) { (result, item) -> [String: String] in
                    var result = result
                    result[item.name] = item.value
                    return result
                }
            }

            return [:]
        }
        set {
            self.queryItems = newValue.map { URLQueryItem(name: $0.key, value: $0.value)}
        }
    }
}
