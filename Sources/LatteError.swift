import Foundation

enum LatteError: LocalizedError {
    case unexpected(message: String)
}

extension LatteError {
    public var errorDescription: String? {
        switch self {
        case let .unexpected(message):
            return message
        }
    }
}
