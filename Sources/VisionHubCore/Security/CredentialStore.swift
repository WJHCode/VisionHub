import Foundation
import Security

public protocol CredentialStoring: Sendable {
    func save(_ credentials: MediaSourceCredentials, id: String) throws
    func credentials(id: String) throws -> MediaSourceCredentials?
    func delete(id: String) throws
}

public enum CredentialStoreError: Error, Equatable {
    case encodingFailed
    case decodingFailed
    case keychainStatus(OSStatus)
}

public final class KeychainCredentialStore: CredentialStoring, @unchecked Sendable {
    private let service: String

    public init(service: String = "VisionHub.MediaServerCredentials") {
        self.service = service
    }

    public func save(_ credentials: MediaSourceCredentials, id: String) throws {
        let data = try JSONEncoder().encode(credentials)
        try delete(id: id)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CredentialStoreError.keychainStatus(status)
        }
    }

    public func credentials(id: String) throws -> MediaSourceCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw CredentialStoreError.keychainStatus(status)
        }

        guard let data = result as? Data else {
            throw CredentialStoreError.decodingFailed
        }

        return try JSONDecoder().decode(MediaSourceCredentials.self, from: data)
    }

    public func delete(id: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychainStatus(status)
        }
    }
}

public final class InMemoryCredentialStore: CredentialStoring, @unchecked Sendable {
    private var storage: [String: MediaSourceCredentials] = [:]

    public init() {}

    public func save(_ credentials: MediaSourceCredentials, id: String) {
        storage[id] = credentials
    }

    public func credentials(id: String) -> MediaSourceCredentials? {
        storage[id]
    }

    public func delete(id: String) {
        storage[id] = nil
    }
}
