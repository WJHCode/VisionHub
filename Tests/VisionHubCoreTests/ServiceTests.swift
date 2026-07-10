import XCTest
@testable import VisionHubCore

@MainActor
final class ServiceTests: XCTestCase {
    func testPlaybackSaveCoordinatorThrottlesTenSecondTicks() {
        let coordinator = PlaybackSaveCoordinator(interval: 10)
        let start = Date(timeIntervalSince1970: 1_000)

        XCTAssertTrue(coordinator.shouldSavePlaybackTick(now: start))
        XCTAssertFalse(coordinator.shouldSavePlaybackTick(now: start.addingTimeInterval(9)))
        XCTAssertTrue(coordinator.shouldSavePlaybackTick(now: start.addingTimeInterval(10)))
        XCTAssertFalse(coordinator.shouldSavePlaybackTick(now: start.addingTimeInterval(19)))
        XCTAssertTrue(coordinator.shouldSavePlaybackTick(now: start.addingTimeInterval(20)))
    }

    func testInMemoryCredentialStoreSavesLoadsAndDeletesCredentials() throws {
        let store: any CredentialStoring = InMemoryCredentialStore()
        let id = UUID().uuidString
        let credentials = MediaSourceCredentials(username: "nas-user", password: "secret")

        try store.save(credentials, id: id)
        XCTAssertEqual(try store.credentials(id: id), credentials)

        try store.delete(id: id)
        XCTAssertNil(try store.credentials(id: id))
    }

    func testTMDBProviderRequiresAPIKey() async {
        let provider = TMDBMetadataProvider(apiKey: "")

        do {
            _ = try await provider.search(MetadataSearchQuery(title: "Arrival"))
            XCTFail("Expected missing API key error.")
        } catch MetadataProviderError.missingAPIKey {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
