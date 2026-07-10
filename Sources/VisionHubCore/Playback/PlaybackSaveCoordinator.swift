import Foundation

@MainActor
public final class PlaybackSaveCoordinator {
    private let interval: TimeInterval
    private var lastSavedAt: Date?

    public init(interval: TimeInterval = 10) {
        self.interval = interval
    }

    public func shouldSavePlaybackTick(now: Date = Date()) -> Bool {
        guard let lastSavedAt else {
            self.lastSavedAt = now
            return true
        }

        guard now.timeIntervalSince(lastSavedAt) >= interval else {
            return false
        }

        self.lastSavedAt = now
        return true
    }

    public func markImmediateSave(now: Date = Date()) {
        lastSavedAt = now
    }

    public func reset() {
        lastSavedAt = nil
    }
}
