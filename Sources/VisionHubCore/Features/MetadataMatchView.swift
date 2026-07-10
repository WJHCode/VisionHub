import SwiftUI

struct MetadataMatchView: View {
    @Environment(\.dismiss) private var dismiss

    let candidates: [MediaMetadata]
    let onSelect: (MediaMetadata) -> Void

    var body: some View {
        NavigationStack {
            List(candidates) { metadata in
                Button {
                    onSelect(metadata)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(metadata.title).font(.headline)
                        if let releaseYear = metadata.releaseYear {
                            Text(String(releaseYear))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if !metadata.overview.isEmpty {
                            Text(metadata.overview)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Choose Metadata")
            .toolbar {
                Button("Cancel") { dismiss() }
            }
        }
        .platformEditorFrame(width: 520, height: 480)
    }
}

struct MetadataAPIKeyEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                SecureField("TMDB API Key", text: $apiKey)
                Text("The key is stored in Keychain and is never written to SwiftData or CloudKit.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Metadata Provider")
            .toolbar {
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(apiKey)
                    dismiss()
                }
                .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .platformEditorFrame(width: 440, height: 260)
    }
}
