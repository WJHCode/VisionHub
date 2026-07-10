import Foundation

public protocol MediaSourceProvider: Sendable {
    var supportedProtocol: MediaProtocolType { get }

    func testConnection(server: MediaServer, credentials: MediaSourceCredentials?) async throws
    func browse(server: MediaServer, path: String, credentials: MediaSourceCredentials?) async throws -> [MediaFile]
    func playableURL(for file: MediaFile, server: MediaServer, credentials: MediaSourceCredentials?) async throws -> URL
}

public enum MediaSourceError: Error, Equatable {
    case unsupportedProtocol(MediaProtocolType)
    case invalidServerHost
    case invalidURL
    case requestFailed(Int)
}

public struct WebDAVMediaSourceProvider: MediaSourceProvider {
    public let supportedProtocol: MediaProtocolType = .webDAV
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func testConnection(server: MediaServer, credentials: MediaSourceCredentials?) async throws {
        let url = try baseURL(for: server, path: server.basePath)
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("0", forHTTPHeaderField: "Depth")
        apply(credentials: credentials, to: &request)

        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    public func browse(server: MediaServer, path: String, credentials: MediaSourceCredentials?) async throws -> [MediaFile] {
        let url = try baseURL(for: server, path: path)
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue("1", forHTTPHeaderField: "Depth")
        apply(credentials: credentials, to: &request)

        let (_, response) = try await session.data(for: request)
        try validate(response: response)

        // XML parsing belongs behind this provider; return an empty result until the parser lands.
        return []
    }

    public func playableURL(
        for file: MediaFile,
        server: MediaServer,
        credentials: MediaSourceCredentials?
    ) async throws -> URL {
        try baseURL(for: server, path: file.path)
    }

    private func baseURL(for server: MediaServer, path: String) throws -> URL {
        guard !server.host.isEmpty else {
            throw MediaSourceError.invalidServerHost
        }

        let scheme = server.host.hasPrefix("http://") || server.host.hasPrefix("https://") ? "" : "https://"
        guard let base = URL(string: "\(scheme)\(server.host)") else {
            throw MediaSourceError.invalidURL
        }

        return base.appending(path: path)
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

public struct SMBMediaSourceProviderPlaceholder: MediaSourceProvider {
    public let supportedProtocol: MediaProtocolType = .smb

    public init() {}

    public func testConnection(server: MediaServer, credentials: MediaSourceCredentials?) async throws {
        throw MediaSourceError.unsupportedProtocol(.smb)
    }

    public func browse(server: MediaServer, path: String, credentials: MediaSourceCredentials?) async throws -> [MediaFile] {
        throw MediaSourceError.unsupportedProtocol(.smb)
    }

    public func playableURL(for file: MediaFile, server: MediaServer, credentials: MediaSourceCredentials?) async throws -> URL {
        throw MediaSourceError.unsupportedProtocol(.smb)
    }
}
