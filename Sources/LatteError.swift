import Foundation

// Implement LocalizedError to customize localizedDescription
enum LatteError: LocalizedError, CustomNSError {
    case unexpected(message: String)

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
}

extension LatteError {
    public var errorDescription: String? {
        switch self {
        case let .unexpected(message):
            return message
        }
    }
}
