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
}
