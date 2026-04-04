import SwiftUI
import SwiftData

struct ContentView: View {
    struct ConflictInfo: Identifiable {
        let id = UUID()
        let noteId: PersistentIdentifier
        let local: String
        let remote: String
        let remoteRevision: String
    }
    
    @State private var selectedNote: Note?
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var activeConflict: ConflictInfo?
    @State private var showingCommandPalette = false
    @State private var showingGlobalSearch = false
    @State private var showingRuleManager = false
    @State private var isAuthenticated = false
    @State private var selectionRange: NSRange?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    
    @Query private var notes: [Note]
    @Environment(ThemeManager.self) private var themeManager
    
    private static let syncCoordinator = SyncCoordinator()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedNote: $selectedNote)
        } content: {
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
                            
                            Button(action: { triggerSync(for: note) }) {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(isSyncing || !isAuthenticated)
                            .keyboardShortcut("s", modifiers: .command)
                            .help("Sync changes with Google Docs (Cmd+S)")
                        } else {
                            Button(action: { publishDraft(note) }) {
                                Label("Publish to Google Docs", systemImage: "arrow.up.doc.fill")
                            }
                            .disabled(isSyncing || !isAuthenticated)
                            .buttonStyle(.borderedProminent)
                        }
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
                    ), selectionRange: $selectionRange,
                    onPromoteAction: { selectedText in
                        promoteToActionItem(selectedText, for: note)
                    })
                }
            } else {
                Text("Select a note to begin")
                    .foregroundColor(.secondary)
            }
        } detail: {
            TaskSidebarView(selectedNote: $selectedNote)
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 600)
        .toolbar {
            ToolbarItem(placement: .status) {
                Button(action: {
                    withAnimation {
                        if columnVisibility == .all {
                            columnVisibility = .doubleColumn
                        } else {
                            columnVisibility = .all
                        }
                    }
                }) {
                    Label("Toggle Tasks", systemImage: "sidebar.right")
                }
                .help("Toggle Task Sidebar (Right)")
            }
        }
        .sheet(isPresented: $showingRuleManager) {
            RuleManagerView()
        }
        .sheet(item: $activeConflict) { info in
            ConflictResolutionView(local: info.local, remote: info.remote) { resolvedContent in
                resolveConflict(info, with: resolvedContent)
            } onCancel: {
                activeConflict = nil
            }
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
            
            if showingGlobalSearch {
                GlobalSearchOverlayView(
                    isVisible: $showingGlobalSearch,
                    notes: notes,
                    onResultSelect: { note, snippet in
                        MainActor.assumeIsolated {
                            selectedNote = note
                            if let snippet = snippet {
                                selectionRange = snippet.absoluteRange
                            }
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncAllNotes)) { _ in
            syncAllNotes()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openRules)) { _ in
            showingRuleManager = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openGlobalSearch)) { _ in
            showingGlobalSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCommandPalette)) { _ in
            showingCommandPalette = true
        }
        .onAppear {
            isAuthenticated = AuthManager.shared.isAuthenticated()
        }
        .background {
            Group {
                Button("") {
                    showingCommandPalette.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
                
                Button("") {
                    showingGlobalSearch.toggle()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            }
            .opacity(0)
        }
    }

    private func login() {
        guard let window = NSApp.keyWindow else { return }
        Task {
            do {
                try await AuthManager.shared.authorize(in: window)
                await MainActor.run {
                    self.isAuthenticated = AuthManager.shared.isAuthenticated()
                }
            } catch {
                syncError = "Login failed: \(error.localizedDescription)"
            }
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
            } catch let error as SyncError {
                await MainActor.run {
                    isSyncing = false
                    if case let .conflict(local, remote, rev) = error {
                        activeConflict = ConflictInfo(noteId: note.persistentModelID, local: local, remote: remote, remoteRevision: rev)
                    } else {
                        syncError = error.localizedDescription
                    }
                }
            } catch {
                await MainActor.run {
                    syncError = error.localizedDescription
                    isSyncing = false
                }
            }
        }
    }

    private func resolveConflict(_ info: ConflictInfo, with content: String) {
        guard let note = try? modelContext.model(for: info.noteId) as? Note else { return }
        
        note.content = content
        note.lastSyncedRevision = info.remoteRevision
        
        do {
            try modelContext.save()
            activeConflict = nil
            // Trigger sync again to push the resolved version
            triggerSync(for: note)
        } catch {
            syncError = "Failed to resolve conflict: \(error.localizedDescription)"
            activeConflict = nil
        }
    }

    private func publishDraft(_ note: Note) {
        guard !isSyncing else { return }
        
        isSyncing = true
        syncError = nil
        
        Task {
            do {
                // 1. Get/Create Folder Structure
                let rootFolder = try await Self.syncCoordinator.gDrive.getOrCreateFolder(named: "updoc")
                let subfolderName = note.meetingID != nil ? "Meetings" : "General"
                let subfolderId = try await Self.syncCoordinator.gDrive.getOrCreateFolder(named: subfolderName, parentId: rootFolder)
                
                // 2. Create Doc
                let docId = try await Self.syncCoordinator.gDrive.createDoc(name: note.title, parentId: subfolderId)
                
                // 3. Link and Initial Sync
                await MainActor.run {
                    note.googleDocId = docId
                }
                
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
