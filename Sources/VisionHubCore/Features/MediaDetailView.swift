import SwiftData
import SwiftUI

public struct MediaDetailView: View {
    @Environment(\.modelContext) private var modelContext

    private let item: MediaItem
    private let currentUserStore: CurrentUserStore
    @State private var metadataCandidates: [MediaMetadata] = []
    @State private var isShowingMetadataMatches = false
    @State private var isShowingAPIKeyEditor = false
    @State private var isMatchingMetadata = false
    @State private var metadataMessage: String?

    public init(item: MediaItem, currentUserStore: CurrentUserStore) {
        self.item = item
        self.currentUserStore = currentUserStore
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .top, spacing: 32) {
                poster

                VStack(alignment: .leading, spacing: 18) {
                    Text(item.title)
                        .font(.largeTitle.bold())

                    Text(item.kind.rawValue.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    progressSummary

                    NavigationLink {
                        PlaybackView(
                            mediaItem: item,
                            url: playbackURL,
                            currentUserStore: currentUserStore
                        )
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(playbackURL == nil)

                    Button("Match Metadata", systemImage: "sparkles") {
                        Task { await searchMetadata() }
                    }
                    .disabled(isMatchingMetadata)
                }
            }

            Spacer()
        }
        .padding(48)
        .navigationTitle(item.title)
        .sheet(isPresented: $isShowingMetadataMatches) {
            MetadataMatchView(candidates: metadataCandidates) { metadata in
                confirm(metadata)
            }
        }
        .sheet(isPresented: $isShowingAPIKeyEditor) {
            MetadataAPIKeyEditorView { apiKey in
                do {
                    try MetadataAPIKeyStore().save(apiKey)
                    Task { await searchMetadata() }
                } catch {
                    metadataMessage = "Unable to save API key: \(error.localizedDescription)"
                }
            }
        }
        .alert("Metadata", isPresented: Binding(
            get: { metadataMessage != nil },
            set: { if !$0 { metadataMessage = nil } }
        )) {
            Button("OK", role: .cancel) { metadataMessage = nil }
        } message: {
            Text(metadataMessage ?? "")
        }
    }

    private var poster: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: 260, height: 390)
            .overlay {
                Image(systemName: "film")
                    .font(.system(size: 54))
                    .foregroundStyle(.secondary)
            }
    }

    private var progressSummary: some View {
        let progress = currentProgress()
        return VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progress)
                .frame(maxWidth: 360)

            Text(progress > 0 ? "\(Int(progress * 100))% watched" : "Not started")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var playbackURL: URL? {
        if let playableURL = item.playableURL {
            return playableURL
        }
        guard item.id.hasPrefix("sample:") else { return nil }
        return URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")
    }

    private func currentProgress() -> Double {
        guard let userId = currentUserStore.currentProfile?.id, item.duration > 0 else {
            return 0
        }

        let id = PlaybackProgress.stableId(userId: userId, mediaId: item.id)
        let descriptor = FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.id == id }
        )
        let progress = try? modelContext.fetch(descriptor).first
        return min(max((progress?.lastPlayedTime ?? 0) / item.duration, 0), 1)
    }

    private func searchMetadata() async {
        isMatchingMetadata = true
        defer { isMatchingMetadata = false }
        do {
            guard let apiKey = try MetadataAPIKeyStore().apiKey(), !apiKey.isEmpty else {
                isShowingAPIKeyEditor = true
                return
            }
            let service = MetadataMatchingService(
                context: modelContext,
                provider: TMDBMetadataProvider(apiKey: apiKey)
            )
            if try MetadataCacheStore(context: modelContext).cachedMetadata(mediaId: item.id) != nil {
                _ = try await service.resolve(item)
                metadataMessage = "Cached metadata applied."
                return
            }
            metadataCandidates = try await service.candidates(for: item)
            if metadataCandidates.isEmpty {
                metadataMessage = "No metadata matches found."
            } else {
                isShowingMetadataMatches = true
            }
        } catch {
            metadataMessage = "Metadata search failed: \(error.localizedDescription)"
        }
    }

    private func confirm(_ metadata: MediaMetadata) {
        do {
            let service = MetadataMatchingService(
                context: modelContext,
                provider: TMDBMetadataProvider(apiKey: "cached-selection")
            )
            _ = try service.confirm(metadata, for: item)
        } catch {
            metadataMessage = "Unable to apply metadata: \(error.localizedDescription)"
        }
    }
}
