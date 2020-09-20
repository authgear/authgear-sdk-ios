import Foundation
import Security

protocol ContainerStorage {
    func setRefreshToken(namespace: String, token: String) throws
    func setAnonymousKeyId(namespace: String, kid: String) throws
    func getRefreshToken(namespace: String) throws -> String?
    func getAnonymousKeyId(namespace: String) throws -> String?
    func delRefreshToken(namespace: String) throws
    func delAnonymousKeyId(namespace: String) throws
}

protocol StorageDriver {
    func get(key: String) throws -> String?
    func set(key: String, value: String) throws
    func del(key: String) throws
}

protocol HasStorageDriver {
    var storageDriver: StorageDriver { get }
}

protocol StorageKeyConvertible {
    func keyRefreshToken(namespace: String) -> String
    func keyAnonymousKeyId(namespace: String) -> String
}

extension ContainerStorage where Self: HasStorageDriver & StorageKeyConvertible {
    func setRefreshToken(namespace: String, token: String) throws {
        try storageDriver.set(key: keyRefreshToken(namespace: namespace), value: token)
    }

    func setAnonymousKeyId(namespace: String, kid: String) throws {
        try storageDriver.set(key: keyAnonymousKeyId(namespace: namespace), value: kid)
    }

    func getRefreshToken(namespace: String) throws -> String? {
        try storageDriver.get(key: keyRefreshToken(namespace: namespace))
    }

    func getAnonymousKeyId(namespace: String) throws -> String? {
        try storageDriver.get(key: keyAnonymousKeyId(namespace: namespace))
    }

    func delRefreshToken(namespace: String) throws {
        try storageDriver.del(key: keyRefreshToken(namespace: namespace))
    }

    func delAnonymousKeyId(namespace: String) throws {
        try storageDriver.del(key: keyAnonymousKeyId(namespace: namespace))
    }
}

class DefaultContainerStorage: ContainerStorage, HasStorageDriver, StorageKeyConvertible {
    let storageDriver: StorageDriver

    init(storageDriver: StorageDriver) {
        self.storageDriver = storageDriver
    }

    private func scopedKey(_ key: String) -> String {
        "authgear_\(key)"
    }

    public func keyRefreshToken(namespace: String) -> String {
        scopedKey("\(namespace)_refreshToken")
    }

    public func keyAnonymousKeyId(namespace: String) -> String {
        scopedKey("\(namespace)_anonymousKeyID")
    }
}

class MemoryStorageDriver: StorageDriver {
    private var backingStorage = [String: String]()

    func get(key: String) throws -> String? {
        backingStorage[key]
    }

    func set(key: String, value: String) throws {
        backingStorage[key] = value
    }

    func del(key: String) throws {
        backingStorage.removeValue(forKey: key)
    }
}

enum KeychainError: Error {
    case encoding
    case unhandledError(status: OSStatus)
}

class KeychainStorageDriver: StorageDriver {
    func get(key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: kCFBooleanTrue as Any
        ]

        var result: AnyObject?

        let status = withUnsafeMutablePointer(to: &result) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        switch status {
        case errSecSuccess:
            guard
                let valueData = result as? Data,
                let value = String(data: valueData, encoding: .utf8)
            else { throw KeychainError.encoding }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    func set(key: String, value: String) throws {
        let status: OSStatus
        if try get(key: key) != nil {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]

            let update: [String: Any] = [kSecValueData as String: value.data(using: .utf8)!]
            status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: value.data(using: .utf8)!
            ]

            status = SecItemAdd(query as CFDictionary, nil)
        }

        if status == errSecSuccess {
            return
        } else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    func del(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
}
