import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedNote: Note?
    @State private var isSyncing = false
    @State private var syncError: String?
    
    private static let syncCoordinator = SyncCoordinator()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedNote: $selectedNote)
        } detail: {
            if let note = selectedNote {
                VStack(spacing: 0) {
                    HStack {
                        Text(note.title)
                            .font(.headline)
                        
                        if isSyncing {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.leading, 8)
                        }
                        
                        Spacer()
                        
                        if let _ = note.googleDocId {
                            Button(action: openInBrowser) {
                                Label("Open in Google Docs", systemImage: "arrow.up.right.square")
                            }
                            .help("Open linked Google Doc in browser")
                        }
                        
                        Button(action: { triggerSync(for: note) }) {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isSyncing)
                        .keyboardShortcut("s", modifiers: .command)
                        .help("Sync changes with Google Docs (Cmd+S)")
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    if let error = syncError {
                        Text("Sync Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    EditorView(text: Binding(
                        get: { note.content },
                        set: { note.content = $0 }
                    ), assetIds: Binding(
                        get: { note.assetIds },
                        set: { note.assetIds = $0 }
                    ))
                }
            } else {
                Text("Select a note to begin")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func openInBrowser() {
        guard let docId = selectedNote?.googleDocId,
              let url = URL(string: "https://docs.google.com/document/d/\(docId)") else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func triggerSync(for note: Note) {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        Task {
            do {
                try await Self.syncCoordinator.sync(noteId: note.persistentModelID, in: modelContext)
                await MainActor.run {
                    isSyncing = false
                }
            } catch {
                await MainActor.run {
                    syncError = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }
}
