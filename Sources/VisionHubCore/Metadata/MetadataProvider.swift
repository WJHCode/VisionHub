import Foundation

public protocol MetadataProvider: Sendable {
    var providerName: String { get }
    func search(_ query: MetadataSearchQuery) async throws -> [MediaMetadata]
}

public enum MetadataProviderError: Error, Equatable {
    case missingAPIKey
    case invalidResponse
}

public struct TMDBMetadataProvider: MetadataProvider {
    public let providerName = "TMDB"
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func search(_ query: MetadataSearchQuery) async throws -> [MediaMetadata] {
        guard !apiKey.isEmpty else {
            throw MetadataProviderError.missingAPIKey
        }

        var components = URLComponents(string: "https://api.themoviedb.org/3/search/movie")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query.title),
            URLQueryItem(name: "year", value: query.year.map(String.init))
        ].compactMap { $0.value == nil ? nil : $0 }

        guard let url = components?.url else {
            throw MetadataProviderError.invalidResponse
        }

        let (data, _) = try await session.data(from: url)
        let response = try JSONDecoder().decode(TMDBSearchResponse.self, from: data)

        return response.results.map { result in
            MediaMetadata(
                id: "tmdb:\(result.id)",
                title: result.title,
                overview: result.overview ?? "",
                releaseYear: result.releaseDate.flatMap { String($0.prefix(4)) }.flatMap(Int.init),
                posterURL: result.posterPath.map { URL(string: "https://image.tmdb.org/t/p/w500\($0)") } ?? nil,
                backdropURL: result.backdropPath.map { URL(string: "https://image.tmdb.org/t/p/w1280\($0)") } ?? nil,
                providerName: providerName,
                providerIdentifier: String(result.id)
            )
        }
    }
}

private struct TMDBSearchResponse: Decodable {
    var results: [TMDBSearchResult]
}

private struct TMDBSearchResult: Decodable {
    var id: Int
    var title: String
    var overview: String?
    var releaseDate: String?
    var posterPath: String?
    var backdropPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case overview
        case releaseDate = "release_date"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
    }
}
