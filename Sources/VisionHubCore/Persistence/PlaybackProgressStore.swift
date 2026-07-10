import Foundation
import SwiftData

@MainActor
public protocol PlaybackProgressStoring {
    func progress(userId: UUID, mediaId: String) throws -> PlaybackProgress?

    func saveProgress(
        userId: UUID,
        mediaId: String,
        time: Double,
        duration: Double,
        forceFinished: Bool
    ) throws -> PlaybackProgress
}

public struct SwiftDataPlaybackProgressStore: PlaybackProgressStoring {
    private let context: ModelContext
    private let finishThreshold: Double

    public init(context: ModelContext, finishThreshold: Double = 0.95) {
        self.context = context
        self.finishThreshold = finishThreshold
    }

    public func progress(userId: UUID, mediaId: String) throws -> PlaybackProgress? {
        let id = PlaybackProgress.stableId(userId: userId, mediaId: mediaId)
        let descriptor = FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.id == id },
            sortBy: [SortDescriptor(\PlaybackProgress.updatedAt, order: .reverse)]
        )
        let matches = try context.fetch(descriptor)
        guard let newest = matches.first else { return nil }

        // CloudKit can temporarily surface duplicate logical records. Keep the
        // newest value and collapse older copies at the query boundary.
        for duplicate in matches.dropFirst() {
            context.delete(duplicate)
        }
        if matches.count > 1 {
            try context.save()
        }
        return newest
    }

    @discardableResult
    public func saveProgress(
        userId: UUID,
        mediaId: String,
        time: Double,
        duration: Double,
        forceFinished: Bool = false
    ) throws -> PlaybackProgress {
        let id = PlaybackProgress.stableId(userId: userId, mediaId: mediaId)
        let existing = try progress(userId: userId, mediaId: mediaId)
        let isFinished = forceFinished || (duration > 0 && time / duration >= finishThreshold)

        let model = existing ?? PlaybackProgress(
            id: id,
            userId: userId,
            mediaId: mediaId
        )

        model.lastPlayedTime = time
        model.duration = duration
        model.isFinished = isFinished
        model.updatedAt = Date()

        if existing == nil {
            context.insert(model)
        }

        try context.save()
        return model
    }

    /// Applies an incoming CloudKit value only when it is newer than the local
    /// logical record. The stable ID keeps the merge scoped to one user/media pair.
    @discardableResult
    public func merge(_ incoming: PlaybackProgress) throws -> PlaybackProgress {
        let expectedId = PlaybackProgress.stableId(
            userId: incoming.userId,
            mediaId: incoming.mediaId
        )
        let existing = try progress(userId: incoming.userId, mediaId: incoming.mediaId)

        guard let existing else {
            incoming.id = expectedId
            context.insert(incoming)
            try context.save()
            return incoming
        }

        guard incoming.updatedAt > existing.updatedAt else {
            return existing
        }

        existing.lastPlayedTime = incoming.lastPlayedTime
        existing.duration = incoming.duration
        existing.isFinished = incoming.isFinished
        existing.updatedAt = incoming.updatedAt
        try context.save()
        return existing
    }
}
