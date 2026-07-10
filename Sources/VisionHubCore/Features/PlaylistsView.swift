import SwiftData
import SwiftUI

public struct PlaylistsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var playlists: [Playlist]

    private let userId: UUID
    @State private var isAdding = false
    @State private var editingPlaylist: Playlist?
    @State private var title = ""

    public init(userId: UUID) {
        self.userId = userId
        _playlists = Query(
            filter: #Predicate { $0.userId == userId },
            sort: [SortDescriptor(\Playlist.updatedAt, order: .reverse)]
        )
    }

    public var body: some View {
        List {
            ForEach(playlists) { playlist in
                NavigationLink {
                    PlaylistDetailView(playlist: playlist, userId: userId)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.title).font(.headline)
                        Text("\(playlist.mediaIds.count) videos")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .contextMenu {
                    Button("Rename") {
                        title = playlist.title
                        editingPlaylist = playlist
                    }
                    Button("Delete", role: .destructive) {
                        try? store.delete(playlist, userId: userId)
                    }
                }
            }
        }
        .navigationTitle("Playlists")
        .toolbar {
            Button("New Playlist", systemImage: "plus") {
                title = ""
                isAdding = true
            }
        }
        .overlay {
            if playlists.isEmpty {
                ContentUnavailableView(
                    "No Playlists",
                    systemImage: "rectangle.stack.badge.plus",
                    description: Text("Create a playlist, then add media from its context menu.")
                )
            }
        }
        .alert("New Playlist", isPresented: $isAdding) {
            TextField("Title", text: $title)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                _ = try? store.create(userId: userId, title: title)
            }
        }
        .alert("Rename Playlist", isPresented: Binding(
            get: { editingPlaylist != nil },
            set: { if !$0 { editingPlaylist = nil } }
        )) {
            TextField("Title", text: $title)
            Button("Cancel", role: .cancel) { editingPlaylist = nil }
            Button("Save") {
                if let editingPlaylist {
                    try? store.rename(editingPlaylist, userId: userId, title: title)
                }
                editingPlaylist = nil
            }
        }
    }

    private var store: PlaylistStore {
        PlaylistStore(context: modelContext)
    }
}

private struct PlaylistDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaItem.title) private var mediaItems: [MediaItem]

    let playlist: Playlist
    let userId: UUID

    var body: some View {
        List(items) { item in
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                    Text(item.kind.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Remove", systemImage: "minus.circle", role: .destructive) {
                    try? PlaylistStore(context: modelContext).remove(
                        mediaId: item.id,
                        from: playlist,
                        userId: userId
                    )
                }
                .buttonStyle(.borderless)
            }
        }
        .navigationTitle(playlist.title)
        .overlay {
            if items.isEmpty {
                ContentUnavailableView(
                    "Playlist Is Empty",
                    systemImage: "film.stack",
                    description: Text("Add media from the library context menu.")
                )
            }
        }
    }

    private var items: [MediaItem] {
        let ids = Set(playlist.mediaIds)
        return mediaItems.filter { ids.contains($0.id) }
    }
}
