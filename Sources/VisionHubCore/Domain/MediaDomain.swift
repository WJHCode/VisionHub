import Foundation

public enum MediaProtocolType: String, CaseIterable, Codable, Identifiable, Sendable {
    case smb = "SMB"
    case webDAV = "WebDAV"

    public var id: String { rawValue }
}

public enum MediaKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case movie
    case episode
    case folder
    case unknown

    public var id: String { rawValue }
}

public enum MetadataStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case pending
    case matched
    case failed
    case localOnly

    public var id: String { rawValue }
}

public struct MediaSourceCredentials: Codable, Equatable, Sendable {
    public var username: String
    public var password: String

    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct MediaFile: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var serverId: UUID
    public var path: String
    public var title: String
    public var kind: MediaKind
    public var sizeInBytes: Int64
    public var modifiedAt: Date?
    public var playableURL: URL?

    public init(
        id: String,
        serverId: UUID,
        path: String,
        title: String,
        kind: MediaKind = .unknown,
        sizeInBytes: Int64 = 0,
        modifiedAt: Date? = nil,
        playableURL: URL? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.path = path
        self.title = title
        self.kind = kind
        self.sizeInBytes = sizeInBytes
        self.modifiedAt = modifiedAt
        self.playableURL = playableURL
    }
}

public struct MetadataSearchQuery: Codable, Equatable, Sendable {
    public var title: String
    public var year: Int?
    public var kind: MediaKind

    public init(title: String, year: Int? = nil, kind: MediaKind = .movie) {
        self.title = title
        self.year = year
        self.kind = kind
    }
}

public struct MediaMetadata: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var overview: String
    public var releaseYear: Int?
    public var posterURL: URL?
    public var backdropURL: URL?
    public var providerName: String
    public var providerIdentifier: String

    public init(
        id: String,
        title: String,
        overview: String = "",
        releaseYear: Int? = nil,
        posterURL: URL? = nil,
        backdropURL: URL? = nil,
        providerName: String,
        providerIdentifier: String
    ) {
        self.id = id
        self.title = title
        self.overview = overview
        self.releaseYear = releaseYear
        self.posterURL = posterURL
        self.backdropURL = backdropURL
        self.providerName = providerName
        self.providerIdentifier = providerIdentifier
    }
}
