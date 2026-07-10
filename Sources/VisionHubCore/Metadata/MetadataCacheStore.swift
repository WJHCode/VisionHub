import Foundation
import SwiftData

public struct MetadataCacheStore {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    @MainActor
    public func cachedMetadata(mediaId: String) throws -> MetadataCache? {
        var descriptor = FetchDescriptor<MetadataCache>(
            predicate: #Predicate { $0.mediaId == mediaId }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    @MainActor
    @discardableResult
    public func save(_ metadata: MediaMetadata, mediaId: String) throws -> MetadataCache {
        let id = "\(metadata.providerName)::\(metadata.providerIdentifier)"
        let existing = try cachedMetadata(mediaId: mediaId)
        let cache = existing ?? MetadataCache(
            id: id,
            mediaId: mediaId,
            providerName: metadata.providerName,
            providerIdentifier: metadata.providerIdentifier,
            title: metadata.title
        )

        cache.title = metadata.title
        cache.overview = metadata.overview
        cache.releaseYear = metadata.releaseYear
        cache.posterURLString = metadata.posterURL?.absoluteString
        cache.backdropURLString = metadata.backdropURL?.absoluteString
        cache.updatedAt = Date()

        if existing == nil {
            context.insert(cache)
        }

        try context.save()
        return cache
    }
}
