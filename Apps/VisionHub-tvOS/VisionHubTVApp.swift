import SwiftUI
import VisionHubCore

@main
struct VisionHubTVApp: App {
    private let modelContainer = VisionHubAppFactory.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            VisionHubRootView()
        }
        .modelContainer(modelContainer)
    }
}
