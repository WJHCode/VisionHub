import Foundation
import SwiftData

public struct MediaScanResult: Sendable, Equatable {
    public var files: [MediaFile]
    public var visitedDirectories: Int

    public init(files: [MediaFile], visitedDirectories: Int) {
        self.files = files
        self.visitedDirectories = visitedDirectories
    }
}

public struct MediaLibraryScanner: Sendable {
    private let provider: any MediaSourceProvider
    private let maximumDirectories: Int
    private let retryCount: Int

    public init(
        provider: any MediaSourceProvider,
        maximumDirectories: Int = 2_000,
        retryCount: Int = 2
    ) {
        self.provider = provider
        self.maximumDirectories = maximumDirectories
        self.retryCount = retryCount
    }

    public func scan(
        server: MediaServerConfiguration,
        rootPath: String,
        credentials: MediaSourceCredentials?
    ) async throws -> MediaScanResult {
        var queue = [rootPath]
        var visited = Set<String>()
        var media: [MediaFile] = []

        while !queue.isEmpty {
            try Task.checkCancellation()
            let path = queue.removeFirst()
            guard visited.insert(path).inserted else { continue }
            guard visited.count <= maximumDirectories else {
                throw MediaSourceError.scanLimitExceeded
            }

            let children = try await browseWithRetry(
                server: server,
                path: path,
                credentials: credentials
            )
            for child in children {
                if child.kind == .folder {
                    queue.append(child.path)
                } else if child.kind == .movie || child.kind == .episode {
                    media.append(child)
                }
            }
        }

        return MediaScanResult(files: media, visitedDirectories: visited.count)
    }

    private func browseWithRetry(
        server: MediaServerConfiguration,
        path: String,
        credentials: MediaSourceCredentials?
    ) async throws -> [MediaFile] {
        var attempt = 0
        while true {
            do {
                return try await provider.browse(server: server, path: path, credentials: credentials)
            } catch {
                guard attempt < retryCount else { throw error }
                attempt += 1
                try await Task.sleep(for: .milliseconds(150 * attempt))
            }
        }
    }
}

@MainActor
public struct MediaLibraryImporter {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    public func apply(_ result: MediaScanResult, serverId: UUID, removeMissing: Bool = true) throws -> [MediaItem] {
        let descriptor = FetchDescriptor<MediaItem>(
            predicate: #Predicate { $0.serverId == serverId }
        )
        let existing = try context.fetch(descriptor)
        var existingById = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let scannedIds = Set(result.files.map(\.id))
        var imported: [MediaItem] = []

        for file in result.files {
            let item = existingById.removeValue(forKey: file.id) ?? MediaItem(
                id: file.id,
                serverId: serverId,
                path: file.path,
                title: file.title,
                kind: file.kind
            )
            item.path = file.path
            item.title = file.title
            item.kind = file.kind
            item.sizeInBytes = file.sizeInBytes
            item.sourceModifiedAt = file.modifiedAt
            item.playableURLString = file.playableURL?.absoluteString
            item.updatedAt = Date()
            if item.modelContext == nil {
                context.insert(item)
            }
            imported.append(item)
        }

        if removeMissing {
            existing.filter { !scannedIds.contains($0.id) }.forEach(context.delete)
        }
        try context.save()
        return imported
    }
}
