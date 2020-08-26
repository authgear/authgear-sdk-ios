//
//  Storage.swift
//  Authgear-iOS
//
//  Created by Peter Cheng on 31/8/2020.
//

import Foundation
import Security

internal protocol ContainerStorage {
    func setRefreshToken(namespace: String, token: String) throws
    func setAnonymousKeyId(namespace: String, kid: String) throws
    func getRefreshToken(namespace: String) throws -> String?
    func getAnonymousKeyId(namespace: String) throws -> String?
    func delRefreshToken(namespace: String) throws
    func delAnonymousKeyId(namespace: String) throws
}

internal protocol StorageDriver {
    func get(key: String) throws -> String?
    func set(key: String, value: String) throws
    func del(key: String) throws
}

internal protocol HasStorageDriver {
    var storageDriver: StorageDriver { get }
}


internal protocol StorageKeyConvertible {
    func keyRefreshToken(namespace: String) -> String
    func keyAnonymousKeyId(namespace: String) -> String
}

internal extension ContainerStorage where Self: HasStorageDriver & StorageKeyConvertible {
    func setRefreshToken(namespace: String, token: String) throws {
        try self.storageDriver.set(key: self.keyRefreshToken(namespace: namespace), value: token)
    }

    func setAnonymousKeyId(namespace: String, kid: String) throws {
        try self.storageDriver.set(key: self.keyAnonymousKeyId(namespace: namespace), value: kid)
    }

    func getRefreshToken(namespace: String) throws -> String? {
        try self.storageDriver.get(key: self.keyRefreshToken(namespace: namespace))
    }

    func getAnonymousKeyId(namespace: String) throws -> String? {
        try self.storageDriver.get(key: self.keyAnonymousKeyId(namespace: namespace))
    }

    func delRefreshToken(namespace: String) throws {
        try self.storageDriver.del(key: self.keyRefreshToken(namespace: namespace))
    }

    func delAnonymousKeyId(namespace: String) throws {
        try self.storageDriver.del(key: self.keyAnonymousKeyId(namespace: namespace))
    }
}

internal class DefaultContainerStorage: ContainerStorage ,HasStorageDriver, StorageKeyConvertible {
    internal let storageDriver: StorageDriver

    init(storageDriver: StorageDriver) {
        self.storageDriver = storageDriver
    }

    private func scopedKey(_ key: String) -> String {
        return "authgear_\(key)"
    }

    public func keyRefreshToken(namespace: String) -> String {
        return self.scopedKey("\(namespace)_refreshToken")
    }

    public func keyAnonymousKeyId(namespace: String) -> String {
        return self.scopedKey("\(namespace)_anonymousKeyID")
    }
}

internal class MemoryStorageDriver: StorageDriver {


    private var backingStorage = [String: String]()

    func get(key: String) throws -> String? {
        self.backingStorage[key]
    }

    func set(key: String, value: String) throws {
        self.backingStorage[key] = value
    }

    func del(key: String) throws {
        self.backingStorage.removeValue(forKey: key)
    }
}

internal enum KeychainError: Error {
    case encoding
    case unhandledError(status: OSStatus)
}

internal class KeychainStorageDriver: StorageDriver {

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
        if try self.get(key: key) != nil {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key
            ]

            let update: [String: Any] = [
                kSecValueData as String: value.data(using: .utf8)!
            ]
            status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: value.data(using: .utf8)!,
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
            kSecAttrAccount as String: key,
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
