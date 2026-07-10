import AVKit
import SwiftData
import SwiftUI

public struct PlaybackView: View {
    @Environment(\.modelContext) private var modelContext

    private let mediaItem: MediaItem
    private let url: URL?
    private let currentUserStore: CurrentUserStore

    @State private var engine = AVPlayerEngine()
    @State private var saveCoordinator = PlaybackSaveCoordinator()

    public init(mediaItem: MediaItem, url: URL?, currentUserStore: CurrentUserStore) {
        self.mediaItem = mediaItem
        self.url = url
        self.currentUserStore = currentUserStore
    }

    public var body: some View {
        Group {
            if url == nil {
                ContentUnavailableView(
                    "Unable to Play",
                    systemImage: "exclamationmark.triangle",
                    description: Text("This media item does not have a playable URL yet.")
                )
            } else {
                VideoPlayer(player: engine.player)
                    .ignoresSafeArea()
            }
        }
        .task {
            await startPlayback()
        }
        .task(id: mediaItem.id) {
            await runProgressAutosaveLoop()
        }
        .onDisappear {
            saveProgress(force: true)
            engine.pause()
        }
    }

    private func startPlayback() async {
        guard let url else { return }
        engine.load(url: url)

        if let progress = try? progressStore().progress(
            userId: currentUserStore.currentProfile?.id ?? UUID(),
            mediaId: mediaItem.id
        ), !progress.isFinished, progress.lastPlayedTime > 5 {
            await engine.seek(to: progress.lastPlayedTime)
        }

        engine.play()
    }

    private func saveProgress(force: Bool = false) {
        guard let userId = currentUserStore.currentProfile?.id else { return }
        guard force || saveCoordinator.shouldSavePlaybackTick() else { return }

        _ = try? progressStore().saveProgress(
            userId: userId,
            mediaId: mediaItem.id,
            time: engine.currentTime,
            duration: max(engine.duration, mediaItem.duration),
            forceFinished: false
        )
    }

    private func progressStore() -> SwiftDataPlaybackProgressStore {
        SwiftDataPlaybackProgressStore(context: modelContext)
    }

    private func runProgressAutosaveLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            saveProgress()
        }
    }
}
