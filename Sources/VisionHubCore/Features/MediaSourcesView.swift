import SwiftData
import SwiftUI

public struct MediaSourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaServer.name) private var servers: [MediaServer]

    @State private var isAddingServer = false
    @State private var editingServer: MediaServer?
    @State private var scanningServerId: UUID?
    @State private var statusMessage: String?

    private let credentialStore: any CredentialStoring

    public init(credentialStore: any CredentialStoring = KeychainCredentialStore()) {
        self.credentialStore = credentialStore
    }

    public var body: some View {
        List {
            ForEach(servers) { server in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(server.name).font(.headline)
                            Text("\(server.protocolType.rawValue) · \(server.host)\(server.basePath)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if scanningServerId == server.id {
                            ProgressView()
                        }
                    }

                    HStack {
                        Button("Test & Scan", systemImage: "arrow.triangle.2.circlepath") {
                            Task { await scan(server) }
                        }
                        .disabled(scanningServerId != nil)

                        Button("Edit", systemImage: "pencil") {
                            editingServer = server
                        }

                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(server)
                        }
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("Media Sources")
        .toolbar {
            Button("Add Source", systemImage: "plus") {
                isAddingServer = true
            }
        }
        .overlay {
            if servers.isEmpty {
                ContentUnavailableView(
                    "No Media Sources",
                    systemImage: "externaldrive.connected.to.line.below",
                    description: Text("Add a WebDAV server to browse and scan your library.")
                )
            }
        }
        .alert("Media Source", isPresented: Binding(
            get: { statusMessage != nil },
            set: { if !$0 { statusMessage = nil } }
        )) {
            Button("OK", role: .cancel) { statusMessage = nil }
        } message: {
            Text(statusMessage ?? "")
        }
        .sheet(isPresented: $isAddingServer) {
            MediaServerEditorView(server: nil) { draft in
                create(draft)
            }
        }
        .sheet(item: $editingServer) { server in
            MediaServerEditorView(server: server) { draft in
                update(server, with: draft)
            }
        }
    }

    private func create(_ draft: MediaServerDraft) {
        do {
            _ = try store.create(
                name: draft.name,
                host: draft.host,
                basePath: draft.basePath,
                protocolType: draft.protocolType,
                username: draft.username,
                password: draft.password.isEmpty ? nil : draft.password
            )
        } catch {
            statusMessage = "Unable to save source: \(error.localizedDescription)"
        }
    }

    private func update(_ server: MediaServer, with draft: MediaServerDraft) {
        do {
            try store.update(
                server,
                name: draft.name,
                host: draft.host,
                basePath: draft.basePath,
                protocolType: draft.protocolType,
                username: draft.username,
                password: draft.password.isEmpty ? nil : draft.password
            )
        } catch {
            statusMessage = "Unable to update source: \(error.localizedDescription)"
        }
    }

    private func delete(_ server: MediaServer) {
        do {
            let serverId = server.id
            let items = try modelContext.fetch(FetchDescriptor<MediaItem>(
                predicate: #Predicate { $0.serverId == serverId }
            ))
            items.forEach(modelContext.delete)
            try store.delete(server)
        } catch {
            statusMessage = "Unable to delete source: \(error.localizedDescription)"
        }
    }

    private func scan(_ server: MediaServer) async {
        scanningServerId = server.id
        defer { scanningServerId = nil }

        do {
            let configuration = server.configuration
            let credentials = try store.credentials(for: server)
            let provider: any MediaSourceProvider = configuration.protocolType == .webDAV
                ? WebDAVMediaSourceProvider()
                : SMBMediaSourceProviderPlaceholder()

            try await provider.testConnection(server: configuration, credentials: credentials)
            let scanResult = try await MediaLibraryScanner(provider: provider).scan(
                server: configuration,
                rootPath: configuration.basePath,
                credentials: credentials
            )
            var playableFiles: [MediaFile] = []
            for var file in scanResult.files {
                file.playableURL = try await provider.playableURL(
                    for: file,
                    server: configuration,
                    credentials: credentials
                )
                playableFiles.append(file)
            }
            let result = MediaScanResult(
                files: playableFiles,
                visitedDirectories: scanResult.visitedDirectories
            )
            try MediaLibraryImporter(context: modelContext).apply(result, serverId: configuration.id)
            statusMessage = "Scan complete: \(result.files.count) videos in \(result.visitedDirectories) folders."
        } catch is CancellationError {
            statusMessage = "Scan cancelled."
        } catch {
            statusMessage = "Source scan failed: \(error.localizedDescription)"
        }
    }

    private var store: MediaServerStore {
        MediaServerStore(context: modelContext, credentials: credentialStore)
    }
}

private struct MediaServerDraft {
    var name: String
    var host: String
    var basePath: String
    var protocolType: MediaProtocolType
    var username: String
    var password: String
}

private struct MediaServerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MediaServerDraft
    private let onSave: (MediaServerDraft) -> Void

    init(server: MediaServer?, onSave: @escaping (MediaServerDraft) -> Void) {
        _draft = State(initialValue: MediaServerDraft(
            name: server?.name ?? "",
            host: server?.host ?? "",
            basePath: server?.basePath ?? "/",
            protocolType: server?.protocolType ?? .webDAV,
            username: server?.username ?? "",
            password: ""
        ))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $draft.name)
                TextField("Host", text: $draft.host)
                    .textContentType(.URL)
                TextField("Base Path", text: $draft.basePath)
                Picker("Protocol", selection: $draft.protocolType) {
                    ForEach(MediaProtocolType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                TextField("Username", text: $draft.username)
                    .textContentType(.username)
                SecureField("Password (leave empty to keep current)", text: $draft.password)
                    .textContentType(.password)
            }
            .navigationTitle("Media Source")
            .toolbar {
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(draft)
                    dismiss()
                }
                .disabled(
                    draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    draft.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )
            }
        }
        .platformEditorFrame(width: 480, height: 420)
    }
}
