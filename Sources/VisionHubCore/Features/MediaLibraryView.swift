import SwiftData
import SwiftUI

public struct MediaLibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaItem.title) private var items: [MediaItem]

    private let currentUserStore: CurrentUserStore

    public init(currentUserStore: CurrentUserStore) {
        self.currentUserStore = currentUserStore
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 28) {
                    ForEach(items) { item in
                        NavigationLink(value: item.id) {
                            MediaPosterCard(item: item, progress: progress(for: item))
                                .platformPosterCard()
                                .visionHubContextMenu(
                                    media: item,
                                    rename: {},
                                    delete: { delete(item) }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 36)
            }
            .navigationTitle("VisionHub")
            .toolbar {
                Button(action: seedSampleLibrary) {
                    Label("Add Samples", systemImage: "plus")
                }

                Button(action: currentUserStore.clear) {
                    Label("Switch Profile", systemImage: "person.2")
                }
            }
            .navigationDestination(for: String.self) { mediaId in
                if let item = items.first(where: { $0.id == mediaId }) {
                    MediaDetailView(item: item, currentUserStore: currentUserStore)
                }
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "No Media Yet",
                        systemImage: "film.stack",
                        description: Text("Add a WebDAV source or use samples while the source browser is being built.")
                    )
                }
            }
        }
    }

    private var columns: [GridItem] {
        #if os(tvOS)
        [GridItem(.adaptive(minimum: 240), spacing: 34)]
        #else
        [GridItem(.adaptive(minimum: 180), spacing: 22)]
        #endif
    }

    private func progress(for item: MediaItem) -> Double {
        guard
            let userId = currentUserStore.currentProfile?.id,
            item.duration > 0
        else {
            return 0
        }

        let id = PlaybackProgress.stableId(userId: userId, mediaId: item.id)
        let descriptor = FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.id == id }
        )
        let progress = try? modelContext.fetch(descriptor).first
        return min(max((progress?.lastPlayedTime ?? 0) / item.duration, 0), 1)
    }

    private func delete(_ item: MediaItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }

    private func seedSampleLibrary() {
        guard items.isEmpty else { return }
        let serverId = UUID()
        let samples = [
            MediaItem(id: "sample:arrival", serverId: serverId, path: "/Movies/Arrival.mp4", title: "Arrival", kind: .movie, duration: 6960),
            MediaItem(id: "sample:foundation-s01e01", serverId: serverId, path: "/Shows/Foundation/S01E01.mp4", title: "Foundation S01E01", kind: .episode, duration: 3540),
            MediaItem(id: "sample:planet-earth", serverId: serverId, path: "/Documentaries/Planet Earth.mp4", title: "Planet Earth", kind: .movie, duration: 3120)
        ]

        samples.forEach(modelContext.insert)
        try? modelContext.save()
    }
}

private struct MediaPosterCard: View {
    let item: MediaItem
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .overlay {
                        if let url = item.posterURL {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "film")
                                    .font(.system(size: 42))
                                    .foregroundStyle(.secondary)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: item.kind == .episode ? "play.tv" : "film")
                                .font(.system(size: 42))
                                .foregroundStyle(.secondary)
                        }
                    }

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .padding(10)
                    .opacity(progress > 0 ? 1 : 0)
            }

            Text(item.title)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}
