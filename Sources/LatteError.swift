import Foundation

enum LatteError: LocalizedError, CustomNSError {
    case unexpected(message: String)
    case invalidShortLink
    case timeout

    // Implements CustomNSError
    public static var errorDomain: String { "LatteError" }
    public var errorCode: Int {
        switch self {
        case .unexpected:
            return 0
        case .invalidShortLink:
            return 1
        case .timeout:
            return 2
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [:]
        switch self {
        case let .unexpected(msg):
            info["message"] = msg
        case .invalidShortLink:
            info["message"] = "invalid short link"
        case .timeout:
            info["message"] = "timeout"
        }
        return info
    }

    // Implements LocalizedError
    public var errorDescription: String? {
        switch self {
        case let .unexpected(message):
            return message
        case .invalidShortLink:
            return "invalid short link"
        case .timeout:
            return "timeout"
        }
    }
}
