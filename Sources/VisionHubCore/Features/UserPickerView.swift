import SwiftData
import SwiftUI

public struct UserPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]

    private let currentUserStore: CurrentUserStore

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
                }

                Button(action: addProfile) {
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
    }

    private func addProfile() {
        let profile = UserProfile(
            name: "Viewer \(profiles.count + 1)",
            avatarEmoji: ["🙂", "😎", "🤖", "🎬", "🍿"].randomElement() ?? "🙂"
        )
        modelContext.insert(profile)
        try? modelContext.save()
        currentUserStore.select(profile)
    }

    private func seedDefaultProfileIfNeeded() {
        guard profiles.isEmpty else { return }
        let profile = UserProfile(name: "Home", avatarEmoji: "🍿")
        modelContext.insert(profile)
        try? modelContext.save()
    }
}
