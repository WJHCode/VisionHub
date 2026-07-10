import SwiftData
import SwiftUI

public struct UserPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    private let currentUserStore: CurrentUserStore
    @State private var editedProfile: UserProfile?
    @State private var isAddingProfile = false

    public init(currentUserStore: CurrentUserStore) {
        self.currentUserStore = currentUserStore
    }

    public var body: some View {
        VStack(spacing: 36) {
            Text("Who's watching?")
                .font(.largeTitle.bold())

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 28)], spacing: 28) {
                ForEach(profiles) { profile in
                    Button {
                        currentUserStore.select(profile)
                    } label: {
                        VStack(spacing: 14) {
                            Text(profile.avatarEmoji)
                                .font(.system(size: 76))
                                .frame(width: 132, height: 132)
                                .background(.thinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Text(profile.name)
                                .font(.headline)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .platformPosterCard()
                    .contextMenu {
                        Button("Edit Profile") {
                            editedProfile = profile
                        }
                        Button("Delete Profile", role: .destructive) {
                            delete(profile)
                        }
                    }
                }

                Button {
                    isAddingProfile = true
                } label: {
                    VStack(spacing: 14) {
                        Image(systemName: "plus")
                            .font(.system(size: 44, weight: .semibold))
                            .frame(width: 132, height: 132)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text("Add Profile")
                            .font(.headline)
                    }
                }
                .buttonStyle(.plain)
                .platformPosterCard()
            }
            .frame(maxWidth: 900)
        }
        .padding(48)
        .task {
            seedDefaultProfileIfNeeded()
        }
        .sheet(item: $editedProfile) { profile in
            ProfileEditorView(profile: profile) { name, emoji in
                profile.name = name
                profile.avatarEmoji = emoji
                try? modelContext.save()
            }
        }
        .sheet(isPresented: $isAddingProfile) {
            ProfileEditorView(profile: nil) { name, emoji in
                addProfile(name: name, emoji: emoji)
            }
        }
    }

    private func addProfile(name: String, emoji: String) {
        let profile = UserProfile(
            name: name,
            avatarEmoji: emoji
        )
        modelContext.insert(profile)
        try? modelContext.save()
        currentUserStore.select(profile)
    }

    private func delete(_ profile: UserProfile) {
        let userId = profile.id
        let progress = (try? modelContext.fetch(FetchDescriptor<PlaybackProgress>(
            predicate: #Predicate { $0.userId == userId }
        ))) ?? []
        let playlists = (try? modelContext.fetch(FetchDescriptor<Playlist>(
            predicate: #Predicate { $0.userId == userId }
        ))) ?? []
        progress.forEach(modelContext.delete)
        playlists.forEach(modelContext.delete)
        modelContext.delete(profile)
        try? modelContext.save()
    }

    private func seedDefaultProfileIfNeeded() {
        guard profiles.isEmpty else { return }
        let profile = UserProfile(name: "Home", avatarEmoji: "🍿")
        modelContext.insert(profile)
        try? modelContext.save()
    }
}

private struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String

    private let onSave: (String, String) -> Void

    init(profile: UserProfile?, onSave: @escaping (String, String) -> Void) {
        _name = State(initialValue: profile?.name ?? "")
        _emoji = State(initialValue: profile?.avatarEmoji ?? "🙂")
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Avatar Emoji", text: $emoji)
            }
            .navigationTitle("Profile")
            .toolbar {
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        emoji.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    dismiss()
                }
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .platformEditorFrame(width: 360, height: 240)
    }
}
