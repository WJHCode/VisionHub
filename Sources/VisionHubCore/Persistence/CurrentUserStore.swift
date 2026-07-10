import Foundation
import Observation
import SwiftData

@MainActor
@Observable
public final class CurrentUserStore {
    public private(set) var currentProfile: UserProfile?

    private let defaults: UserDefaults
    private let key = "VisionHub.currentProfileId"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func restore(from context: ModelContext) throws {
        guard
            let rawValue = defaults.string(forKey: key),
            let profileId = UUID(uuidString: rawValue)
        else {
            currentProfile = nil
            return
        }

        var descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.id == profileId }
        )
        descriptor.fetchLimit = 1
        currentProfile = try context.fetch(descriptor).first
    }

    public func select(_ profile: UserProfile) {
        currentProfile = profile
        defaults.set(profile.id.uuidString, forKey: key)
    }

    public func clear() {
        currentProfile = nil
        defaults.removeObject(forKey: key)
    }

    public func deleteCurrentProfile(from context: ModelContext) throws {
        guard let profile = currentProfile else { return }
        let userId = profile.id

        let progress = try context.fetch(FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.userId == userId }
        ))
        let playlists = try context.fetch(FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.userId == userId }
        ))

        progress.forEach(context.delete)
        playlists.forEach(context.delete)
        context.delete(profile)
        try context.save()
        clear()
    }
}
