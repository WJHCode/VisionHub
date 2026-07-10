import AVKit
import SwiftData
import SwiftUI

public struct PlaybackView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    private let mediaItem: MediaItem
    private let url: URL?
    private let currentUserStore: CurrentUserStore

    @State private var engine = AVPlayerEngine()
    @State private var saveCoordinator = PlaybackSaveCoordinator()
    @State private var wasPlaying = false

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
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                saveProgress(force: true)
            }
        }
    }

    private func startPlayback() async {
        guard let url else { return }
        engine.load(url: url)

        guard let userId = currentUserStore.currentProfile?.id else { return }

        if let progress = try? progressStore().progress(
            userId: userId,
            mediaId: mediaItem.id
        ), !progress.isFinished, progress.lastPlayedTime > 5 {
            await engine.seek(to: progress.lastPlayedTime)
        }

        engine.play()
        wasPlaying = true
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
        if force {
            saveCoordinator.markImmediateSave()
        }
    }

    private func progressStore() -> SwiftDataPlaybackProgressStore {
        SwiftDataPlaybackProgressStore(context: modelContext)
    }

    private func runProgressAutosaveLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            if wasPlaying && !engine.isPlaying {
                saveProgress(force: true)
            }
            wasPlaying = engine.isPlaying
            saveProgress()
        }
    }
}
