import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedNote: Note?
    private let syncCoordinator = SyncCoordinator()
    @Environment(\.modelContext) private var modelContext
    private let syncTimer = Timer.publish(every: 300, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedNote: $selectedNote)
        } detail: {
            if let note = selectedNote {
                VStack(spacing: 0) {
                    HStack {
                        Text(note.title)
                            .font(.headline)
                        Spacer()
                        if let _ = note.googleDocId {
                            Button(action: openInBrowser) {
                                Label("Open in Google Docs", systemImage: "arrow.up.right.square")
                            }
                        }
                        Button(action: { triggerSync(for: note) }) {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .keyboardShortcut("s", modifiers: .command)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor))
                    
                    Divider()
                    
                    EditorView(text: Binding(
                        get: { note.content },
                        set: { note.content = $0 }
                    ))
                }
                .onReceive(syncTimer) { _ in
                    if let note = selectedNote {
                        triggerSync(for: note)
                    }
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
        Task {
            try? await syncCoordinator.sync(noteId: note.persistentModelID, in: modelContext)
        }
    }
}
