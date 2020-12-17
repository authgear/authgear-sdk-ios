import Foundation

public enum AuthgearError: Error {
    case canceledLogin
    case oauthError(error: String, description: String?)
    case unexpectedError(Error)
    case anonymousUserNotFound
    case unauthenticatedUser
}
