import Foundation
import SwiftData

public enum VisionHubPersistence {
    public static let schema = Schema([
        UserProfile.self,
        MediaServer.self,
        MediaItem.self,
        PlaybackProgress.self,
        Playlist.self,
        MetadataCache.self
    ])

    public static func makeModelContainer(
        cloudKitContainerIdentifier: String? = "iCloud.com.visionhub.app",
        isStoredInMemoryOnly: Bool = false
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly,
            cloudKitDatabase: cloudKitContainerIdentifier.map { .private($0) } ?? .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
