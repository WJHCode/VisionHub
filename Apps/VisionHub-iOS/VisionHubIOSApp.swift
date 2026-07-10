import SwiftUI
import VisionHubCore

@main
struct VisionHubIOSApp: App {
    private let modelContainer = VisionHubAppFactory.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            VisionHubRootView()
        }
        .modelContainer(modelContainer)
    }
}
