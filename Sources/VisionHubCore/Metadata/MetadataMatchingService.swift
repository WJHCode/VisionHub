import Foundation
import SwiftData

@MainActor
public final class MetadataMatchingService {
    private let context: ModelContext
    private let provider: any MetadataProvider
    private let parser: FilenameMetadataParser

    public init(
        context: ModelContext,
        provider: any MetadataProvider,
        parser: FilenameMetadataParser = FilenameMetadataParser()
    ) {
        self.context = context
        self.provider = provider
        self.parser = parser
    }

    /// Returns cached metadata without calling the provider. When uncached, the
    /// first provider result is applied; callers can use `candidates(for:)` when
    /// they want an explicit user-confirmation UI.
    public func resolve(_ item: MediaItem) async throws -> MetadataCache? {
        let cacheStore = MetadataCacheStore(context: context)
        if let cached = try cacheStore.cachedMetadata(mediaId: item.id) {
            apply(cached, to: item)
            try context.save()
            return cached
        }

        guard let selected = try await candidates(for: item).first else {
            item.metadataStatus = .failed
            try context.save()
            return nil
        }

        let cache = try cacheStore.save(selected, mediaId: item.id)
        apply(cache, to: item)
        try context.save()
        return cache
    }

    public func candidates(for item: MediaItem) async throws -> [MediaMetadata] {
        let parsed = parser.parse(item.title.isEmpty ? item.path : item.title)
        return try await provider.search(parsed.searchQuery)
    }

    public func confirm(_ metadata: MediaMetadata, for item: MediaItem) throws -> MetadataCache {
        let cache = try MetadataCacheStore(context: context).save(metadata, mediaId: item.id)
        apply(cache, to: item)
        try context.save()
        return cache
    }

    private func apply(_ cache: MetadataCache, to item: MediaItem) {
        item.title = cache.title
        item.metadataCacheId = cache.id
        item.posterURLString = cache.posterURLString
        item.backdropURLString = cache.backdropURLString
        item.metadataStatus = .matched
        item.updatedAt = Date()
    }
}
