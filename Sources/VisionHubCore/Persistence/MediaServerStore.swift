import Foundation
import SwiftData

public enum MediaServerStoreError: Error, Equatable {
    case emptyName
    case emptyHost
}

@MainActor
public struct MediaServerStore {
    private let context: ModelContext
    private let credentials: any CredentialStoring

    public init(context: ModelContext, credentials: any CredentialStoring) {
        self.context = context
        self.credentials = credentials
    }

    public func servers() throws -> [MediaServer] {
        try context.fetch(FetchDescriptor<MediaServer>(
            sortBy: [SortDescriptor(\MediaServer.name)]
        ))
    }

    @discardableResult
    public func create(
        name: String,
        host: String,
        basePath: String = "/",
        protocolType: MediaProtocolType,
        username: String = "",
        password: String? = nil
    ) throws -> MediaServer {
        let values = try validated(name: name, host: host, basePath: basePath)
        let server = MediaServer(
            name: values.name,
            host: values.host,
            basePath: values.basePath,
            protocolType: protocolType,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        if let password {
            try credentials.save(
                MediaSourceCredentials(username: server.username, password: password),
                id: server.credentialId
            )
        }

        context.insert(server)
        do {
            try context.save()
        } catch {
            try? credentials.delete(id: server.credentialId)
            throw error
        }
        return server
    }

    public func update(
        _ server: MediaServer,
        name: String,
        host: String,
        basePath: String,
        protocolType: MediaProtocolType,
        username: String,
        password: String? = nil
    ) throws {
        let values = try validated(name: name, host: host, basePath: basePath)
        server.name = values.name
        server.host = values.host
        server.basePath = values.basePath
        server.protocolType = protocolType
        server.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        server.updatedAt = Date()

        if let password {
            try credentials.save(
                MediaSourceCredentials(username: server.username, password: password),
                id: server.credentialId
            )
        }
        try context.save()
    }

    public func delete(_ server: MediaServer) throws {
        try credentials.delete(id: server.credentialId)
        context.delete(server)
        try context.save()
    }

    public func credentials(for server: MediaServer) throws -> MediaSourceCredentials? {
        try credentials.credentials(id: server.credentialId)
    }

    private func validated(name: String, host: String, basePath: String) throws -> (name: String, host: String, basePath: String) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else { throw MediaServerStoreError.emptyName }
        guard !normalizedHost.isEmpty else { throw MediaServerStoreError.emptyHost }
        let normalizedPath = basePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return (normalizedName, normalizedHost, normalizedPath.isEmpty ? "/" : normalizedPath)
    }
}
