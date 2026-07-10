import SwiftData
import XCTest
@testable import VisionHubCore

@MainActor
final class PersistenceTests: XCTestCase {
    func testModelContainerCanBeCreatedInMemory() throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )

        XCTAssertNotNil(container)
    }

    func testPlaybackProgressIsScopedByUserAndMedia() throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )
        let context = container.mainContext
        let store = SwiftDataPlaybackProgressStore(context: context)
        let mediaId = "movie:arrival"
        let firstUser = UUID()
        let secondUser = UUID()

        try store.saveProgress(userId: firstUser, mediaId: mediaId, time: 120, duration: 7200, forceFinished: false)
        try store.saveProgress(userId: secondUser, mediaId: mediaId, time: 540, duration: 7200, forceFinished: false)

        let firstProgress = try XCTUnwrap(store.progress(userId: firstUser, mediaId: mediaId))
        let secondProgress = try XCTUnwrap(store.progress(userId: secondUser, mediaId: mediaId))

        XCTAssertEqual(firstProgress.lastPlayedTime, 120)
        XCTAssertEqual(secondProgress.lastPlayedTime, 540)
        XCTAssertNotEqual(firstProgress.id, secondProgress.id)
    }

    func testPlaybackProgressUpsertKeepsOneRecordPerUserAndMedia() throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )
        let context = container.mainContext
        let store = SwiftDataPlaybackProgressStore(context: context)
        let userId = UUID()
        let mediaId = "movie:arrival"

        try store.saveProgress(userId: userId, mediaId: mediaId, time: 120, duration: 7200, forceFinished: false)
        try store.saveProgress(userId: userId, mediaId: mediaId, time: 240, duration: 7200, forceFinished: false)

        let descriptor = FetchDescriptor<PlaybackProgress>()
        let records = try context.fetch(descriptor)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.lastPlayedTime, 240)
    }

    func testPlaybackProgressMarksFinishedNearEnd() throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )
        let store = SwiftDataPlaybackProgressStore(context: container.mainContext)

        let progress = try store.saveProgress(
            userId: UUID(),
            mediaId: "movie:ending",
            time: 96,
            duration: 100,
            forceFinished: false
        )

        XCTAssertTrue(progress.isFinished)
    }

    func testPlaybackProgressMergeKeepsNewestUpdatedAt() throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )
        let store = SwiftDataPlaybackProgressStore(context: container.mainContext)
        let userId = UUID()
        let mediaId = "movie:merge"
        let oldDate = Date(timeIntervalSince1970: 100)
        let newDate = Date(timeIntervalSince1970: 200)

        let local = PlaybackProgress(
            id: PlaybackProgress.stableId(userId: userId, mediaId: mediaId),
            userId: userId,
            mediaId: mediaId,
            lastPlayedTime: 80,
            duration: 100,
            updatedAt: newDate
        )
        container.mainContext.insert(local)
        try container.mainContext.save()

        let olderRemote = PlaybackProgress(
            id: "remote-id",
            userId: userId,
            mediaId: mediaId,
            lastPlayedTime: 10,
            duration: 100,
            updatedAt: oldDate
        )
        XCTAssertEqual(try store.merge(olderRemote).lastPlayedTime, 80)

        let newerRemote = PlaybackProgress(
            id: "remote-id-2",
            userId: userId,
            mediaId: mediaId,
            lastPlayedTime: 95,
            duration: 100,
            isFinished: true,
            updatedAt: newDate.addingTimeInterval(1)
        )
        let merged = try store.merge(newerRemote)
        XCTAssertEqual(merged.lastPlayedTime, 95)
        XCTAssertTrue(merged.isFinished)
    }

    func testPlaylistCRUDIsUserScopedAndAvoidsDuplicateMedia() throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )
        let store = PlaylistStore(context: container.mainContext)
        let owner = UUID()
        let otherUser = UUID()
        let playlist = try store.create(userId: owner, title: " Favorites ")

        try store.add(mediaId: "movie:arrival", to: playlist, userId: owner)
        try store.add(mediaId: "movie:arrival", to: playlist, userId: owner)
        XCTAssertEqual(playlist.title, "Favorites")
        XCTAssertEqual(playlist.mediaIds, ["movie:arrival"])
        XCTAssertEqual(try store.playlists(userId: otherUser).count, 0)
        XCTAssertThrowsError(try store.rename(playlist, userId: otherUser, title: "Leaked"))

        try store.rename(playlist, userId: owner, title: "Weekend")
        XCTAssertEqual(playlist.title, "Weekend")
        try store.remove(mediaId: "movie:arrival", from: playlist, userId: owner)
        XCTAssertTrue(playlist.mediaIds.isEmpty)
        try store.delete(playlist, userId: owner)
        XCTAssertTrue(try store.playlists(userId: owner).isEmpty)
    }

    func testMediaServerCRUDKeepsPasswordOutOfSwiftData() throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )
        let credentials = InMemoryCredentialStore()
        let store = MediaServerStore(context: container.mainContext, credentials: credentials)
        let server = try store.create(
            name: " NAS ",
            host: "https://nas.local",
            protocolType: .webDAV,
            username: "viewer",
            password: "secret"
        )

        XCTAssertEqual(server.name, "NAS")
        XCTAssertFalse(server.credentialId.contains("secret"))
        XCTAssertEqual(try store.credentials(for: server)?.password, "secret")

        try store.update(
            server,
            name: "NAS 2",
            host: "nas.local",
            basePath: "/media",
            protocolType: .webDAV,
            username: "home",
            password: "new-secret"
        )
        XCTAssertEqual(try store.credentials(for: server)?.username, "home")
        try store.delete(server)
        XCTAssertTrue(try store.servers().isEmpty)
        XCTAssertNil(credentials.credentials(id: server.credentialId))
    }

    func testMediaLibraryImporterUpsertsAndRemovesMissingItems() throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )
        let context = container.mainContext
        let serverId = UUID()
        let importer = MediaLibraryImporter(context: context)
        let firstScan = MediaScanResult(files: [
            MediaFile(id: "one", serverId: serverId, path: "/one.mp4", title: "One.mp4", kind: .movie),
            MediaFile(id: "two", serverId: serverId, path: "/two.mp4", title: "Two.mp4", kind: .movie)
        ], visitedDirectories: 1)

        try importer.apply(firstScan, serverId: serverId)
        let secondScan = MediaScanResult(files: [
            MediaFile(id: "one", serverId: serverId, path: "/one.mp4", title: "One Renamed.mp4", kind: .movie)
        ], visitedDirectories: 1)
        try importer.apply(secondScan, serverId: serverId)

        let items = try context.fetch(FetchDescriptor<MediaItem>())
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.id, "one")
        XCTAssertEqual(items.first?.title, "One Renamed.mp4")
    }

    func testMetadataMatchingUsesCacheAfterFirstProviderRequest() async throws {
        let container = try VisionHubPersistence.makeModelContainer(
            cloudKitContainerIdentifier: nil,
            isStoredInMemoryOnly: true
        )
        let item = MediaItem(
            id: "movie:arrival",
            serverId: UUID(),
            path: "/Arrival.2016.mp4",
            title: "Arrival.2016.mp4"
        )
        container.mainContext.insert(item)
        let counter = MetadataRequestCounter()
        let service = MetadataMatchingService(
            context: container.mainContext,
            provider: CountingMetadataProvider(counter: counter)
        )

        let first = try await service.resolve(item)
        let second = try await service.resolve(item)

        XCTAssertEqual(first?.title, "Arrival")
        XCTAssertEqual(second?.title, "Arrival")
        let requestCount = await counter.value
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(item.metadataStatus, .matched)
    }
}

private actor MetadataRequestCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private struct CountingMetadataProvider: MetadataProvider {
    let providerName = "Test"
    let counter: MetadataRequestCounter

    func search(_ query: MetadataSearchQuery) async throws -> [MediaMetadata] {
        await counter.increment()
        return [MediaMetadata(
            id: "test:arrival",
            title: "Arrival",
            releaseYear: 2016,
            providerName: providerName,
            providerIdentifier: "arrival"
        )]
    }
}
