import Foundation
import LocalAuthentication

public enum AuthgearError: Error {
    case cancel
    case unexpectedHttpStatusCode(Int, Data?)
    case serverError(ServerError)
    case oauthError(OAuthError)

    case anonymousUserNotFound

    case biometricPrivateKeyNotFound
    case biometricNotSupportedOrPermissionDenied(Error)
    case biometricNoPasscode(Error)
    case biometricNoEnrollment(Error)
    case biometricLockout(Error)

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

func wrapError(error: Error) -> Error {
    let nsError = error as NSError

    // Cancel
    if (nsError.domain == kLAErrorDomain && nsError.code == kLAErrorUserCancel) {
        return AuthgearError.cancel
    }
    if (nsError.domain == NSOSStatusErrorDomain && nsError.code == errSecUserCanceled) {
        return AuthgearError.cancel
    }

    if (nsError.domain == kLAErrorDomain && nsError.code == kLAErrorBiometryNotAvailable) {
        return AuthgearError.biometricNotSupportedOrPermissionDenied(error)
    }

    if (nsError.domain == kLAErrorDomain && nsError.code == kLAErrorBiometryNotEnrolled) {
        return AuthgearError.biometricNoEnrollment(error)
    }

    if (nsError.domain == kLAErrorDomain && nsError.code == kLAErrorPasscodeNotSet) {
        return AuthgearError.biometricNoPasscode(error)
    }

    if (nsError.domain == kLAErrorDomain && nsError.code == kLAErrorBiometryLockout) {
        return AuthgearError.biometricLockout(error)
    }

    return AuthgearError.error(error)
}
