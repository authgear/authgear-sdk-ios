import Foundation

enum LatteError: LocalizedError, CustomNSError {
    case unexpected(message: String)

    // Implements CustomNSError
    public static var errorDomain: String { "LatteError" }
    public var errorCode: Int {
        switch self {
        case .unexpected:
            return 0
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [:]
        switch self {
        case let .unexpected(msg):
            info["message"] = msg
        }
        return info
    }

    // Implements LocalizedError
    public var errorDescription: String? {
        switch self {
        case let .unexpected(message):
            return message
        }
    }
}
