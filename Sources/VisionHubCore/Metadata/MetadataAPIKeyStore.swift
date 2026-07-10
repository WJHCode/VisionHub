import Foundation

public struct MetadataAPIKeyStore: Sendable {
    private let credentials: any CredentialStoring
    private let credentialId: String

    public init(
        credentials: any CredentialStoring = KeychainCredentialStore(service: "VisionHub.MetadataAPIKeys"),
        credentialId: String = "TMDB"
    ) {
        self.credentials = credentials
        self.credentialId = credentialId
    }

    public func save(_ apiKey: String) throws {
        let normalized = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            try credentials.delete(id: credentialId)
        } else {
            try credentials.save(
                MediaSourceCredentials(username: "api-key", password: normalized),
                id: credentialId
            )
        }
    }

    public func apiKey() throws -> String? {
        try credentials.credentials(id: credentialId)?.password
    }

    public func delete() throws {
        try credentials.delete(id: credentialId)
    }
}
