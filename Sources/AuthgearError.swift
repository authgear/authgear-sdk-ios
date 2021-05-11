import Foundation

public enum AuthgearError: Error {
    case cancel
    case unexpectedHttpStatusCode(Int, Data?)
    case serverError(ServerError)
    case oauthError(OAuthError)
    case anonymousUserNotFound
    case unauthenticatedUser
    case publicKeyNotFound
    case error(Error)
    case osStatus(OSStatus)
}

public struct OAuthError: Error, Decodable {
    let error: String
    let errorDescription: String?
    let errorUri: String?
}

public struct ServerError: Error, Decodable {
    let name: String
    let message: String
    let reason: String
    let info: [String: Any]?

    enum CodingKeys: String, CodingKey {
        case name
        case message
        case reason
        case info
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        message = try values.decode(String.self, forKey: .message)
        reason = try values.decode(String.self, forKey: .reason)
        info = try values.decode([String: Any].self, forKey: .info)
    }
}
