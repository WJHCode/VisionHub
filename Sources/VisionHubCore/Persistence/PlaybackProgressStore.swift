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
        var descriptor = FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
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
}
