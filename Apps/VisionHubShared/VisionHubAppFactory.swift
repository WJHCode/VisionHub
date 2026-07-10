import SwiftData
import SwiftUI
import VisionHubCore

@MainActor
enum VisionHubAppFactory {
    static func makeModelContainer() -> ModelContainer {
        do {
            return try VisionHubPersistence.makeModelContainer()
        } catch {
            fatalError("Unable to create VisionHub ModelContainer: \(error)")
        }
    }
}
