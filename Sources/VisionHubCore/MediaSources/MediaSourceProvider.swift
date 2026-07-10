import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

public protocol MediaSourceProvider: Sendable {
    var supportedProtocol: MediaProtocolType { get }

    func testConnection(server: MediaServerConfiguration, credentials: MediaSourceCredentials?) async throws
    func browse(server: MediaServerConfiguration, path: String, credentials: MediaSourceCredentials?) async throws -> [MediaFile]
    func playableURL(for file: MediaFile, server: MediaServerConfiguration, credentials: MediaSourceCredentials?) async throws -> URL
}

public enum MediaSourceError: Error, Equatable {
    case unsupportedProtocol(MediaProtocolType)
    case invalidServerHost
    case invalidURL
    case requestFailed(Int)
    case malformedResponse
    case scanLimitExceeded
}

public struct WebDAVMediaSourceProvider: MediaSourceProvider {
    public let supportedProtocol: MediaProtocolType = .webDAV
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func testConnection(server: MediaServerConfiguration, credentials: MediaSourceCredentials?) async throws {
        let url = try baseURL(for: server, path: server.basePath)
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        apply(credentials: credentials, to: &request)

        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    public func browse(server: MediaServerConfiguration, path: String, credentials: MediaSourceCredentials?) async throws -> [MediaFile] {
        let url = try baseURL(for: server, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        apply(credentials: credentials, to: &request)

        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try WebDAVMultiStatusParser().parse(
            data: data,
            serverId: server.id,
            excludingPath: url.path
        )
    }

    public func playableURL(
        for file: MediaFile,
        server: MediaServerConfiguration,
        credentials: MediaSourceCredentials?
    ) async throws -> URL {
        try baseURL(for: server, path: file.path)
    }

    private func baseURL(for server: MediaServerConfiguration, path: String) throws -> URL {
        guard !server.host.isEmpty else {
            throw MediaSourceError.invalidServerHost
        }

        let scheme = server.host.hasPrefix("http://") || server.host.hasPrefix("https://") ? "" : "https://"
        guard let base = URL(string: "\(scheme)\(server.host)") else {
            throw MediaSourceError.invalidURL
        }

        guard var components = URLComponents(url: base, resolvingAgainstBaseURL: false) else {
            throw MediaSourceError.invalidURL
        }
        let requestedPath = path.hasPrefix("/") ? path : joinedPath(server.basePath, path)
        components.percentEncodedPath = encodedPath(requestedPath)
        guard let url = components.url else { throw MediaSourceError.invalidURL }
        return url
    }

    private func joinedPath(_ lhs: String, _ rhs: String) -> String {
        let left = lhs.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let right = rhs.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "/" + [left, right].filter { !$0.isEmpty }.joined(separator: "/")
    }

    private func encodedPath(_ path: String) -> String {
        path.split(separator: "/", omittingEmptySubsequences: false)
            .map { String($0).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
    }

    private func apply(credentials: MediaSourceCredentials?, to request: inout URLRequest) {
        guard let credentials else { return }
        let token = "\(credentials.username):\(credentials.password)"
            .data(using: .utf8)?
            .base64EncodedString()
        if let token {
            request.setValue("Basic \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard 200..<300 ~= http.statusCode || http.statusCode == 207 else {
            throw MediaSourceError.requestFailed(http.statusCode)
        }
    }
}

public struct WebDAVMultiStatusParser: Sendable {
    public init() {}

    public func parse(data: Data, serverId: UUID, excludingPath: String? = nil) throws -> [MediaFile] {
        let delegate = WebDAVXMLDelegate(serverId: serverId)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw MediaSourceError.malformedResponse
        }

        let excluded = excludingPath.map(normalizedPath)
        return delegate.files.filter { file in
            guard let excluded else { return true }
            return normalizedPath(file.path) != excluded
        }
    }

    private func normalizedPath(_ path: String) -> String {
        let decoded = path.removingPercentEncoding ?? path
        if decoded.count > 1 {
            return decoded.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        return decoded
    }
}

private final class WebDAVXMLDelegate: NSObject, XMLParserDelegate {
    private let serverId: UUID
    private var currentElement = ""
    private var text = ""
    private var href = ""
    private var contentLength: Int64 = 0
    private var modifiedAt: Date?
    private var isCollection = false

    var files: [MediaFile] = []

    init(serverId: UUID) {
        self.serverId = serverId
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = localName(qName ?? elementName)
        text = ""
        if currentElement == "response" {
            href = ""
            contentLength = 0
            modifiedAt = nil
            isCollection = false
        } else if currentElement == "collection" {
            isCollection = true
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = localName(qName ?? elementName)
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch element {
        case "href":
            href = value
        case "getcontentlength":
            contentLength = Int64(value) ?? 0
        case "getlastmodified":
            modifiedAt = Self.httpDateFormatter.date(from: value)
        case "response":
            appendCurrentFile()
        default:
            break
        }
        currentElement = ""
        text = ""
    }

    private func appendCurrentFile() {
        guard !href.isEmpty else { return }
        let path = URL(string: href)?.path ?? href
        let decodedPath = path.removingPercentEncoding ?? path
        let trimmed = decodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fallbackTitle = isCollection ? "Folder" : "Untitled"
        let title = trimmed.split(separator: "/").last.map(String.init) ?? fallbackTitle
        let kind = isCollection ? MediaKind.folder : Self.mediaKind(for: title)
        files.append(MediaFile(
            id: "\(serverId.uuidString)::\(decodedPath)",
            serverId: serverId,
            path: decodedPath,
            title: title,
            kind: kind,
            sizeInBytes: contentLength,
            modifiedAt: modifiedAt
        ))
    }

    private func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init)?.lowercased() ?? name.lowercased()
    }

    private static func mediaKind(for title: String) -> MediaKind {
        let videoExtensions: Set<String> = ["mp4", "m4v", "mov", "mkv", "avi", "ts", "m2ts", "webm"]
        let ext = (title as NSString).pathExtension.lowercased()
        guard videoExtensions.contains(ext) else { return .unknown }
        return FilenameMetadataParser().parse(title).kind
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}

public struct SMBMediaSourceProviderPlaceholder: MediaSourceProvider {
    public let supportedProtocol: MediaProtocolType = .smb

    public init() {}

    public func testConnection(server: MediaServerConfiguration, credentials: MediaSourceCredentials?) async throws {
        throw MediaSourceError.unsupportedProtocol(.smb)
    }

    public func browse(server: MediaServerConfiguration, path: String, credentials: MediaSourceCredentials?) async throws -> [MediaFile] {
        throw MediaSourceError.unsupportedProtocol(.smb)
    }

    public func playableURL(for file: MediaFile, server: MediaServerConfiguration, credentials: MediaSourceCredentials?) async throws -> URL {
        throw MediaSourceError.unsupportedProtocol(.smb)
    }
}
