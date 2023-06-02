import AuthenticationServices
import Foundation
import LocalAuthentication
import SafariServices

public enum AuthgearError: CustomNSError {
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

    case cannotReauthenticate

    case invalidJWT(String)

    case unauthenticatedUser
    case publicKeyNotFound
    case error(Error)

    public static var errorDomain: String { "AuthgearError" }
    public var errorCode: Int {
        switch self {
        case .cancel:
            return 0
        case .unexpectedHttpStatusCode:
            return 1
        case .serverError:
            return 2
        case .oauthError:
            return 3
        case .anonymousUserNotFound:
            return 4
        case .biometricPrivateKeyNotFound:
            return 5
        case .biometricNotSupportedOrPermissionDenied:
            return 6
        case .biometricNoPasscode:
            return 7
        case .biometricNoEnrollment:
            return 8
        case .biometricLockout:
            return 9
        case .cannotReauthenticate:
            return 10
        case .invalidJWT:
            return 11
        case .unauthenticatedUser:
            return 11
        case .publicKeyNotFound:
            return 11
        case .error:
            return 12
        }
    }

    public var errorUserInfo: [String: Any] {
        var info: [String: Any] = [:]
        switch self {
        case let .unexpectedHttpStatusCode(code, _):
            info["code"] = code
        case let .serverError(err):
            info = err.errorUserInfo
        case let .oauthError(err):
            info = err.errorUserInfo
        case let .biometricNotSupportedOrPermissionDenied(err):
            info["error"] = makeErrorInfo(err)
        case let .biometricNoPasscode(err):
            info["error"] = makeErrorInfo(err)
        case let .biometricNoEnrollment(err):
            info["error"] = makeErrorInfo(err)
        case let .biometricLockout(err):
            info["error"] = makeErrorInfo(err)
        case let .invalidJWT(jwt):
            info["jwt"] = jwt
        case let .error(err):
            info["error"] = makeErrorInfo(err)
        default:
            break
        }
        return info
    }

    private func makeErrorInfo(_ err: Error) -> [String: Any] {
        var info: [String: Any] = [
            "message": err.localizedDescription
        ]
        let nserr = err as NSError
        info["domain"] = nserr.domain
        info["code"] = nserr.code
        info["info"] = nserr.userInfo
        return info
    }
}

public struct OAuthError: Error, CustomNSError, Decodable {
    public let error: String
    public let errorDescription: String?
    public let errorUri: String?
    
    // Implements CustomNSError
    public static var errorDomain: String { "OAuthError" }
    public var errorCode: Int { 0 }
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [
            "error": self.error
        ]
        if let errorDescription = self.errorDescription {
            userInfo["errorDescription"] = errorDescription
        }
        if let errorUri = self.errorUri {
            userInfo["errorUri"] = errorUri
        }
        return userInfo
    }
}

public struct ServerError: Error, CustomNSError, Decodable {
    public let name: String
    public let message: String
    public let reason: String
    public let info: [String: Any]?

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
        info = try? values.decode([String: Any].self, forKey: .info)
    }

    // Implements CustomNSError
    public static var errorDomain: String { "ServerError" }
    public var errorCode: Int { 0 }
    public var errorUserInfo: [String: Any] {
        var userInfo: [String: Any] = [
            "name": self.name,
            "message": self.message,
            "reason": self.reason
        ]
        if let info = self.info {
            userInfo["info"] = info
        }
        return userInfo
    }
}

func wrapError(error: Error) -> Error {
    // No need to wrap.
    if let error = error as? AuthgearError {
        return error
    }

    if #available(iOS 12.0, *) {
        if let asError = error as? ASWebAuthenticationSessionError,
           asError.code == ASWebAuthenticationSessionError.canceledLogin {
            return AuthgearError.cancel
        }
    }

    if let sfError = error as? SFAuthenticationError,
       sfError.code == SFAuthenticationError.canceledLogin {
        return AuthgearError.cancel
    }

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
