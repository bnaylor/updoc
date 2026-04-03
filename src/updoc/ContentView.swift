import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedNote: Note?
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var showingCommandPalette = false
    @State private var showingRuleManager = false
    
    @Query private var notes: [Note]
    @Environment(ThemeManager.self) private var themeManager
    
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
                    ), onPromoteAction: { selectedText in
                        promoteToActionItem(selectedText, for: note)
                    })
                }
            } else {
                Text("Select a note to begin")
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingRuleManager) {
            RuleManagerView()
        }
        .overlay {
            if showingCommandPalette {
                CommandPaletteView(
                    isPresented: $showingCommandPalette,
                    commands: appCommands,
                    notes: notes,
                    onNoteSelect: { note in
                        MainActor.assumeIsolated {
                            selectedNote = note
                        }
                    }
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncAllNotes)) { _ in
            syncAllNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRules)) { _ in
            showingRuleManager = true
        }
        .background {
            Button("") {
                showingCommandPalette.toggle()
            }
            .keyboardShortcut("k", modifiers: .command)
            .opacity(0)
        }
    }
    
    private func promoteToActionItem(_ text: String, for note: Note) {
        // Clean up text: remove checklist markers and whitespace
        var title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let markers = ["[ ]", "[x]", "√"]
        for marker in markers {
            if title.hasPrefix(marker) {
                title = String(title.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        guard !title.isEmpty else { return }
        
        let actionItem = ActionItem(title: title)
        actionItem.note = note
        note.actionItems.append(actionItem)
        modelContext.insert(actionItem)
        
        do {
            try modelContext.save()
        } catch {
            print("Failed to save promoted action item: \(error)")
        }
    }
    
    private var appCommands: [Command] {
        var commands = [
            Command(title: "New Note", subtitle: "App", shortcut: "⌘N") {
                NotificationCenter.default.post(name: .addNewNote, object: nil)
            },
            Command(title: "Sync All Notes", subtitle: "App", shortcut: "⇧⌘S") {
                Task { @MainActor in
                    syncAllNotes()
                }
            },
            Command(title: "Open Template Rules", subtitle: "App", shortcut: "⌘R") {
                Task { @MainActor in
                    showingRuleManager = true
                }
            }
        ]
        
        for theme in AppTheme.allCases {
            commands.append(Command(title: "Switch to \(theme.rawValue) Theme", subtitle: "Theme") {
                Task { @MainActor in
                    themeManager.currentTheme = theme
                }
            })
        }
        
        return commands
    }
    
    private func syncAllNotes() {
        guard !isSyncing else { return }
        
        Task {
            isSyncing = true
            for note in notes {
                if let _ = note.googleDocId {
                    do {
                        try await Self.syncCoordinator.sync(noteId: note.persistentModelID, in: modelContext)
                    } catch {
                        print("Failed to sync note: \(note.title)")
                    }
                }
            }
            isSyncing = false
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
