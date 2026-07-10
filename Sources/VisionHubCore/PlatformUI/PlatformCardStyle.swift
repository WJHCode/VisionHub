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
            .platformHoverEffect()
    }
}

public extension View {
    func platformPosterCard() -> some View {
        modifier(PlatformPosterCardStyle())
    }

    @ViewBuilder
    func platformEditorFrame(width: CGFloat, height: CGFloat) -> some View {
        #if os(macOS)
        frame(minWidth: width, minHeight: height)
        #else
        self
        #endif
    }

    @ViewBuilder
    func visionHubContextMenu(
        media: MediaItem,
        playlists: [Playlist],
        rename: @escaping () -> Void,
        addToPlaylist: @escaping (Playlist) -> Void,
        delete: @escaping () -> Void
    ) -> some View {
        #if os(macOS)
        contextMenu {
            Button("Rename", action: rename)
            if !playlists.isEmpty {
                Menu("Add to Playlist") {
                    ForEach(playlists) { playlist in
                        Button(playlist.title) { addToPlaylist(playlist) }
                    }
                }
            }
            Button("Delete", role: .destructive, action: delete)
        }
        #else
        self
        #endif
    }
}

private struct PlatformHoverModifier: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .scaleEffect(isHovering ? 1.025 : 1)
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.15), value: isHovering)
        #else
        content
        #endif
    }
}

private extension View {
    func platformHoverEffect() -> some View {
        modifier(PlatformHoverModifier())
    }
}
