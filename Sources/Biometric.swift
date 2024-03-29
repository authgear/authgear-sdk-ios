import Foundation
import LocalAuthentication
import Security

@available(iOS 11.3, *)
public enum BiometricAccessConstraint {
    case biometryAny
    case biometryCurrentSet
    case userPresence

    var secAccessControlCreateFlags: SecAccessControlCreateFlags {
        switch self {
        case .biometryAny:
            return SecAccessControlCreateFlags.biometryAny
        case .biometryCurrentSet:
            return SecAccessControlCreateFlags.biometryCurrentSet
        case .userPresence:
            return SecAccessControlCreateFlags.userPresence
        }
    }
}

public enum BiometricLAPolicy {
    case deviceOwnerAuthenticationWithBiometrics
    case deviceOwnerAuthentication

    var laPolicy: LAPolicy {
        switch self {
        case .deviceOwnerAuthenticationWithBiometrics:
            return .deviceOwnerAuthenticationWithBiometrics
        case .deviceOwnerAuthentication:
            return .deviceOwnerAuthentication
        }
    }
}

extension LAContext {
    convenience init(policy: LAPolicy) {
        self.init()
        if case .deviceOwnerAuthenticationWithBiometrics = policy {
            // Hide the fallback button
            // https://developer.apple.com/documentation/localauthentication/lacontext/1514183-localizedfallbacktitle
            self.localizedFallbackTitle = ""
        }
    }
}

@available(iOS 11.3, *)
func generatePrivateKey() throws -> SecKey {
    var error: Unmanaged<CFError>?
    let query: [String: Any] = [
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrKeySizeInBits as String: 2048
    ]
    guard let privateKey = SecKeyCreateRandomKey(query as CFDictionary, &error) else {
        throw AuthgearError.error(error!.takeRetainedValue() as Error)
    }
    return privateKey
}

@available(iOS 11.3, *)
func removePrivateKey(tag: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrApplicationTag as String: tag
    ]

    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}

@available(iOS 11.3, *)
func getPrivateKey(tag: String, laContext: LAContext) throws -> SecKey? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassKey,
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
        kSecAttrApplicationTag as String: tag,
        kSecUseAuthenticationContext as String: laContext,
        kSecReturnRef as String: true
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status != errSecItemNotFound else {
        return nil
    }

    guard status == errSecSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }

    let privateKey = item as! SecKey
    return privateKey
}

@available(iOS 11.3, *)
func addPrivateKey(privateKey: SecKey, tag: String, constraint: BiometricAccessConstraint, laContext: LAContext) throws {
    try removePrivateKey(tag: tag)

    var error: Unmanaged<CFError>?
    guard let accessControl = SecAccessControlCreateWithFlags(
        nil,
        kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
        constraint.secAccessControlCreateFlags,
        &error
    ) else {
        throw AuthgearError.error(error!.takeRetainedValue() as Error)
    }

    let query: [String: Any] = [
        kSecValueRef as String: privateKey,
        kSecClass as String: kSecClassKey,
        kSecAttrApplicationTag as String: tag,
        kSecAttrAccessControl as String: accessControl,
        kSecUseAuthenticationContext as String: laContext
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
    }
}
