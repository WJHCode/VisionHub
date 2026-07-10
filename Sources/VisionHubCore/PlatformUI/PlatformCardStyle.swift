import SwiftUI

public struct PlatformPosterCardStyle: ViewModifier {
    @FocusState private var isFocused: Bool

    public func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isFocused)
            .scaleEffect(isFocused ? 1.06 : 1)
            .shadow(color: .black.opacity(isFocused ? 0.35 : 0.12), radius: isFocused ? 18 : 6)
            .animation(.snappy(duration: 0.18), value: isFocused)
    }
}

public extension View {
    func platformPosterCard() -> some View {
        modifier(PlatformPosterCardStyle())
    }

    @ViewBuilder
    func visionHubContextMenu(media: MediaItem, rename: @escaping () -> Void, delete: @escaping () -> Void) -> some View {
        #if os(macOS)
        contextMenu {
            Button("Rename", action: rename)
            Button("Delete", role: .destructive, action: delete)
        }
        #else
        self
        #endif
    }
}
