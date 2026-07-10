import SwiftUI
import VisionHubCore

@main
struct VisionHubMacApp: App {
    private let modelContainer = VisionHubAppFactory.makeModelContainer()

    var body: some Scene {
        WindowGroup {
            VisionHubRootView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .modelContainer(modelContainer)

        Settings {
            Text("VisionHub Settings")
                .padding()
        }
    }
}
