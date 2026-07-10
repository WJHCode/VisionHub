import AVFoundation
import Foundation

@MainActor
public protocol PlayerEngine: AnyObject {
    var currentTime: Double { get }
    var duration: Double { get }
    var isPlaying: Bool { get }
    var player: AVPlayer { get }

    func load(url: URL)
    func play()
    func pause()
    func seek(to seconds: Double) async
}

@MainActor
public final class AVPlayerEngine: PlayerEngine {
    public private(set) var player: AVPlayer

    public var currentTime: Double {
        player.currentTime().seconds.isFinite ? player.currentTime().seconds : 0
    }

    public var duration: Double {
        let seconds = player.currentItem?.duration.seconds ?? 0
        return seconds.isFinite ? seconds : 0
    }

    public var isPlaying: Bool {
        player.timeControlStatus == .playing
    }

    public init(player: AVPlayer = AVPlayer()) {
        self.player = player
    }

    public func load(url: URL) {
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }

    public func play() {
        player.play()
    }

    public func pause() {
        player.pause()
    }

    public func seek(to seconds: Double) async {
        await player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
}
