import Foundation
import SwiftData

@Model
public final class UserProfile {
    public var id: UUID = UUID()
    public var name: String = "New Viewer"
    public var avatarEmoji: String = "🙂"
    public var createdAt: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String = "New Viewer",
        avatarEmoji: String = "🙂",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.createdAt = createdAt
    }
}

@Model
public final class MediaServer {
    public var id: UUID = UUID()
    public var name: String = "Media Server"
    public var host: String = ""
    public var basePath: String = "/"
    public var protocolRawValue: String = MediaProtocolType.webDAV.rawValue
    public var username: String = ""
    public var credentialId: String = UUID().uuidString
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var protocolType: MediaProtocolType {
        get { MediaProtocolType(rawValue: protocolRawValue) ?? .webDAV }
        set { protocolRawValue = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String = "Media Server",
        host: String = "",
        basePath: String = "/",
        protocolType: MediaProtocolType = .webDAV,
        username: String = "",
        credentialId: String = UUID().uuidString,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.basePath = basePath
        self.protocolRawValue = protocolType.rawValue
        self.username = username
        self.credentialId = credentialId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public extension MediaServer {
    var configuration: MediaServerConfiguration {
        MediaServerConfiguration(
            id: id,
            name: name,
            host: host,
            basePath: basePath,
            protocolType: protocolType,
            username: username,
            credentialId: credentialId
        )
    }
}

@Model
public final class MediaItem {
    public var id: String = ""
    public var serverId: UUID = UUID()
    public var path: String = ""
    public var title: String = ""
    public var kindRawValue: String = MediaKind.unknown.rawValue
    public var metadataStatusRawValue: String = MetadataStatus.pending.rawValue
    public var metadataCacheId: String?
    public var duration: Double = 0
    public var sizeInBytes: Int64 = 0
    public var sourceModifiedAt: Date?
    public var playableURLString: String?
    public var posterURLString: String?
    public var backdropURLString: String?
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public var kind: MediaKind {
        get { MediaKind(rawValue: kindRawValue) ?? .unknown }
        set { kindRawValue = newValue.rawValue }
    }

    public var metadataStatus: MetadataStatus {
        get { MetadataStatus(rawValue: metadataStatusRawValue) ?? .pending }
        set { metadataStatusRawValue = newValue.rawValue }
    }

    public var posterURL: URL? {
        posterURLString.flatMap(URL.init(string:))
    }

    public var playableURL: URL? {
        playableURLString.flatMap(URL.init(string:))
    }

    public init(
        id: String,
        serverId: UUID,
        path: String,
        title: String,
        kind: MediaKind = .unknown,
        metadataStatus: MetadataStatus = .pending,
        metadataCacheId: String? = nil,
        duration: Double = 0,
        sizeInBytes: Int64 = 0,
        sourceModifiedAt: Date? = nil,
        playableURLString: String? = nil,
        posterURLString: String? = nil,
        backdropURLString: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.serverId = serverId
        self.path = path
        self.title = title
        self.kindRawValue = kind.rawValue
        self.metadataStatusRawValue = metadataStatus.rawValue
        self.metadataCacheId = metadataCacheId
        self.duration = duration
        self.sizeInBytes = sizeInBytes
        self.sourceModifiedAt = sourceModifiedAt
        self.playableURLString = playableURLString
        self.posterURLString = posterURLString
        self.backdropURLString = backdropURLString
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class PlaybackProgress {
    public var id: String = ""
    public var userId: UUID = UUID()
    public var mediaId: String = ""
    public var lastPlayedTime: Double = 0
    public var duration: Double = 0
    public var isFinished: Bool = false
    public var updatedAt: Date = Date()

    public init(
        id: String,
        userId: UUID,
        mediaId: String,
        lastPlayedTime: Double = 0,
        duration: Double = 0,
        isFinished: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.mediaId = mediaId
        self.lastPlayedTime = lastPlayedTime
        self.duration = duration
        self.isFinished = isFinished
        self.updatedAt = updatedAt
    }

    public static func stableId(userId: UUID, mediaId: String) -> String {
        "\(userId.uuidString)::\(mediaId)"
    }
}

@Model
public final class Playlist {
    public var id: UUID = UUID()
    public var userId: UUID = UUID()
    public var title: String = "New Playlist"
    public var mediaIds: [String] = []
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        id: UUID = UUID(),
        userId: UUID,
        title: String = "New Playlist",
        mediaIds: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.mediaIds = mediaIds
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
public final class MetadataCache {
    public var id: String = ""
    public var mediaId: String = ""
    public var providerName: String = ""
    public var providerIdentifier: String = ""
    public var title: String = ""
    public var overview: String = ""
    public var releaseYear: Int?
    public var posterURLString: String?
    public var backdropURLString: String?
    public var updatedAt: Date = Date()

    public init(
        id: String,
        mediaId: String,
        providerName: String,
        providerIdentifier: String,
        title: String,
        overview: String = "",
        releaseYear: Int? = nil,
        posterURLString: String? = nil,
        backdropURLString: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.mediaId = mediaId
        self.providerName = providerName
        self.providerIdentifier = providerIdentifier
        self.title = title
        self.overview = overview
        self.releaseYear = releaseYear
        self.posterURLString = posterURLString
        self.backdropURLString = backdropURLString
        self.updatedAt = updatedAt
    }
}
