import SwiftData
import SwiftUI

public struct VisionHubRootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var currentUserStore: CurrentUserStore

    public init(currentUserStore: CurrentUserStore = CurrentUserStore()) {
        _currentUserStore = State(initialValue: currentUserStore)
    }

    public var body: some View {
        Group {
            if currentUserStore.currentProfile == nil {
                UserPickerView(currentUserStore: currentUserStore)
            } else {
                MediaLibraryView(currentUserStore: currentUserStore)
            }
        }
        .task {
            try? currentUserStore.restore(from: modelContext)
        }
    }
}
