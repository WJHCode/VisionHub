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

    func testPlaybackSaveCoordinatorWritesSixTimesAcrossSixtyOneSecondTicks() {
        let coordinator = PlaybackSaveCoordinator(interval: 10)
        let start = Date(timeIntervalSince1970: 2_000)
        let saveCount = (1...60).reduce(into: 0) { count, second in
            if coordinator.shouldSavePlaybackTick(
                now: start.addingTimeInterval(TimeInterval(second))
            ) {
                count += 1
            }
        }

        XCTAssertEqual(saveCount, 6)
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

    func testMetadataAPIKeyStoreUsesCredentialStorage() throws {
        let credentials = InMemoryCredentialStore()
        let store = MetadataAPIKeyStore(credentials: credentials, credentialId: "test-tmdb")

        try store.save(" secret-key ")
        XCTAssertEqual(try store.apiKey(), "secret-key")
        try store.delete()
        XCTAssertNil(try store.apiKey())
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

    func testFilenameParserRecognizesMovieAndEpisodePatterns() {
        let parser = FilenameMetadataParser()

        let movie = parser.parse("Blade.Runner.2049.2017.2160p.mkv")
        XCTAssertEqual(movie.title, "Blade Runner 2049")
        XCTAssertEqual(movie.year, 2017)
        XCTAssertEqual(movie.kind, .movie)

        let episode = parser.parse("Foundation.S02E03.1080p.WEB-DL.mkv")
        XCTAssertEqual(episode.title, "Foundation")
        XCTAssertEqual(episode.kind, .episode)
        XCTAssertEqual(episode.seasonNumber, 2)
        XCTAssertEqual(episode.episodeNumber, 3)

        let alternateEpisode = parser.parse("The Bear 3x04.m4v")
        XCTAssertEqual(alternateEpisode.title, "The Bear")
        XCTAssertEqual(alternateEpisode.seasonNumber, 3)
        XCTAssertEqual(alternateEpisode.episodeNumber, 4)
    }

    func testWebDAVParserReturnsFoldersAndVideoFilesAndSkipsRequestedDirectory() throws {
        let serverId = UUID()
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:response><d:href>/media/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat></d:response>
          <d:response><d:href>/media/Shows/</d:href><d:propstat><d:prop><d:resourcetype><d:collection/></d:resourcetype></d:prop></d:propstat></d:response>
          <d:response><d:href>/media/Arrival%20(2016).mp4</d:href><d:propstat><d:prop><d:getcontentlength>12345</d:getcontentlength><d:getlastmodified>Wed, 08 Jul 2026 10:00:00 GMT</d:getlastmodified><d:resourcetype/></d:prop></d:propstat></d:response>
          <d:response><d:href>/media/readme.txt</d:href><d:propstat><d:prop><d:resourcetype/></d:prop></d:propstat></d:response>
        </d:multistatus>
        """

        let files = try WebDAVMultiStatusParser().parse(
            data: Data(xml.utf8),
            serverId: serverId,
            excludingPath: "/media/"
        )

        XCTAssertEqual(files.count, 3)
        XCTAssertEqual(files.first?.kind, .folder)
        let movie = try XCTUnwrap(files.first { $0.title == "Arrival (2016).mp4" })
        XCTAssertEqual(movie.kind, .movie)
        XCTAssertEqual(movie.sizeInBytes, 12_345)
        XCTAssertNotNil(movie.modifiedAt)
        XCTAssertEqual(files.first { $0.title == "readme.txt" }?.kind, .unknown)
    }

    func testRecursiveScannerTraversesFoldersAndRetries() async throws {
        let server = MediaServerConfiguration(
            id: UUID(),
            name: "NAS",
            host: "nas.local",
            basePath: "/media",
            protocolType: .webDAV,
            username: "",
            credentialId: "test"
        )
        let provider = ScannerProvider(serverId: server.id)
        let scanner = MediaLibraryScanner(provider: provider, retryCount: 1)

        let result = try await scanner.scan(server: server, rootPath: "/media", credentials: nil)

        XCTAssertEqual(result.visitedDirectories, 2)
        XCTAssertEqual(result.files.map(\.title), ["Arrival.2016.mp4"])
        let attempts = await provider.attempts(for: "/media")
        XCTAssertEqual(attempts, 2)
    }
}

private actor ScannerProvider: MediaSourceProvider {
    nonisolated let supportedProtocol: MediaProtocolType = .webDAV
    private let serverId: UUID
    private var counts: [String: Int] = [:]

    init(serverId: UUID) {
        self.serverId = serverId
    }

    func attempts(for path: String) -> Int { counts[path, default: 0] }

    func testConnection(server: MediaServerConfiguration, credentials: MediaSourceCredentials?) async throws {}

    func browse(server: MediaServerConfiguration, path: String, credentials: MediaSourceCredentials?) async throws -> [MediaFile] {
        counts[path, default: 0] += 1
        if path == "/media" && counts[path] == 1 {
            throw MediaSourceError.requestFailed(503)
        }
        if path == "/media" {
            return [MediaFile(
                id: "folder:movies",
                serverId: serverId,
                path: "/media/Movies",
                title: "Movies",
                kind: .folder
            )]
        }
        return [MediaFile(
            id: "movie:arrival",
            serverId: serverId,
            path: "/media/Movies/Arrival.2016.mp4",
            title: "Arrival.2016.mp4",
            kind: .movie
        )]
    }

    func playableURL(for file: MediaFile, server: MediaServerConfiguration, credentials: MediaSourceCredentials?) async throws -> URL {
        URL(string: "https://nas.local\(file.path)")!
    }
}
