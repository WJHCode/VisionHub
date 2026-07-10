import Foundation
import SwiftData

public enum PlaylistStoreError: Error, Equatable {
    case emptyTitle
    case playlistNotFound
    case userMismatch
}

@MainActor
public struct PlaylistStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func playlists(userId: UUID) throws -> [Playlist] {
        let descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\Playlist.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    public func create(userId: UUID, title: String) throws -> Playlist {
        let normalizedTitle = try validated(title: title)
        let playlist = Playlist(userId: userId, title: normalizedTitle)
        context.insert(playlist)
        try context.save()
        return playlist
    }

    public func rename(_ playlist: Playlist, userId: UUID, title: String) throws {
        try validateOwner(of: playlist, userId: userId)
        playlist.title = try validated(title: title)
        playlist.updatedAt = Date()
        try context.save()
    }

    public func delete(_ playlist: Playlist, userId: UUID) throws {
        try validateOwner(of: playlist, userId: userId)
        context.delete(playlist)
        try context.save()
    }

    public func add(mediaId: String, to playlist: Playlist, userId: UUID) throws {
        try validateOwner(of: playlist, userId: userId)
        guard !playlist.mediaIds.contains(mediaId) else { return }
        playlist.mediaIds.append(mediaId)
        playlist.updatedAt = Date()
        try context.save()
    }

    public func remove(mediaId: String, from playlist: Playlist, userId: UUID) throws {
        try validateOwner(of: playlist, userId: userId)
        playlist.mediaIds.removeAll { $0 == mediaId }
        playlist.updatedAt = Date()
        try context.save()
    }

    private func validateOwner(of playlist: Playlist, userId: UUID) throws {
        guard playlist.userId == userId else {
            throw PlaylistStoreError.userMismatch
        }
    }

    private func validated(title: String) throws -> String {
        let normalized = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw PlaylistStoreError.emptyTitle }
        return normalized
    }
}
