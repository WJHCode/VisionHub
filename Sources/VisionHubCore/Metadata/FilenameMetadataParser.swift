import Foundation

public struct FilenameMetadataParser: Sendable {
    public init() {}

    public func parse(_ filename: String) -> ParsedMediaName {
        let basename = (filename as NSString).deletingPathExtension
        let normalized = basename
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        if let episode = firstMatch(
            pattern: #"(?i)\bS(\d{1,2})[ ._-]*E(\d{1,3})\b"#,
            in: normalized
        ) {
            let title = cleanedTitle(String(normalized[..<episode.range.lowerBound]))
            return ParsedMediaName(
                title: title,
                year: extractYear(from: normalized),
                kind: .episode,
                seasonNumber: Int(episode.groups[0]),
                episodeNumber: Int(episode.groups[1])
            )
        }

        if let episode = firstMatch(
            pattern: #"(?i)\b(\d{1,2})x(\d{1,3})\b"#,
            in: normalized
        ) {
            let title = cleanedTitle(String(normalized[..<episode.range.lowerBound]))
            return ParsedMediaName(
                title: title,
                year: extractYear(from: normalized),
                kind: .episode,
                seasonNumber: Int(episode.groups[0]),
                episodeNumber: Int(episode.groups[1])
            )
        }

        // Release names commonly contain a year-like number in the title
        // (for example “Blade Runner 2049 2017”); the trailing year is the
        // release year used by indexers.
        let yearMatch = matches(pattern: #"\b((?:19|20)\d{2})\b"#, in: normalized).last
        let titleSource = yearMatch.map { String(normalized[..<$0.range.lowerBound]) } ?? normalized
        return ParsedMediaName(
            title: cleanedTitle(titleSource),
            year: yearMatch?.groups.first.flatMap(Int.init),
            kind: .movie
        )
    }

    private func extractYear(from value: String) -> Int? {
        matches(pattern: #"\b((?:19|20)\d{2})\b"#, in: value).last?.groups.first.flatMap(Int.init)
    }

    private func cleanedTitle(_ value: String) -> String {
        let releaseTags = #"(?i)\b(2160p|1080p|720p|bluray|web[- ]?dl|webrip|hdtv|x264|x265|hevc|aac)\b.*$"#
        let range = value.range(of: releaseTags, options: .regularExpression)
        let withoutTags = range.map { String(value[..<$0.lowerBound]) } ?? value
        let cleaned = withoutTags
            .replacingOccurrences(of: #"[\[\](){}-]+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Untitled" : cleaned
    }

    private func firstMatch(pattern: String, in value: String) -> (range: Range<String.Index>, groups: [String])? {
        matches(pattern: pattern, in: value).first
    }

    private func matches(pattern: String, in value: String) -> [(range: Range<String.Index>, groups: [String])] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let fullRange = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.matches(in: value, range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: value) else { return nil }
            let groups = (1..<match.numberOfRanges).compactMap { index -> String? in
                guard let groupRange = Range(match.range(at: index), in: value) else { return nil }
                return String(value[groupRange])
            }
            return (range, groups)
        }
    }
}
