import SwiftData
import SwiftUI

public struct MediaDetailView: View {
    @Environment(\.modelContext) private var modelContext

    private let item: MediaItem
    private let currentUserStore: CurrentUserStore

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
                            url: samplePlaybackURL,
                            currentUserStore: currentUserStore
                        )
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(samplePlaybackURL == nil)
                }
            }

            Spacer()
        }
        .padding(48)
        .navigationTitle(item.title)
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

    private var samplePlaybackURL: URL? {
        URL(string: "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8")
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
}
