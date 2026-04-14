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
    @State private var showingSettings = false
    @State private var selectionRange: NSRange?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingTaskSidebar = true
    @State private var deletionManager = DeletionManager()
    @State private var liveSyncManager = LiveSyncManager()
    
    @Query private var notes: [Note]
    @Environment(ThemeManager.self) private var themeManager
    
    private static let syncCoordinator = SyncCoordinator()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedNote: $selectedNote)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
        } content: {
            NoteListView(selectedNote: $selectedNote)
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
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
                            Button(action: { openInBrowser() }) {
                                Label("Open in Google Docs", systemImage: "arrow.up.right.square")
                            }
                            .help("Open linked Google Doc in browser")
                            
                            Button(action: { triggerSync(for: note) }) {
                                Label(
                                    title: { Text(liveSyncManager.isFastPolling ? "Receiving Edits..." : "Sync Now") },
                                    icon: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .foregroundStyle(liveSyncManager.isFastPolling ? .green : .primary)
                                            .symbolEffect(.pulse, options: .repeating, isActive: liveSyncManager.isFastPolling)
                                    }
                                )
                            }
                            .disabled(isSyncing || !AuthManager.shared.isAuthenticated())
                            .keyboardShortcut("s", modifiers: .command)
                            .help("Sync changes with Google Docs (Cmd+S)")                        } else {
                            Button(action: { publishDraft(note) }) {
                                Label("Publish to Google Docs", systemImage: "arrow.up.doc.fill")
                            }
                            .disabled(isSyncing || !AuthManager.shared.isAuthenticated())
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Button {
                            showingTaskSidebar.toggle()
                        } label: {
                            Image(systemName: "sidebar.right")
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Action Items")
                        .padding(.leading, 8)
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
                    .onAppear {
                        NotificationCenter.default.post(name: .focusEditor, object: nil)
                    }
                    .onChange(of: note.id) {
                        NotificationCenter.default.post(name: .focusEditor, object: nil)
                    }
                    .onTapGesture {
                        NotificationCenter.default.post(name: .focusEditor, object: nil)
                    }
                }
                .navigationTitle(note.title)
                .inspector(isPresented: $showingTaskSidebar) {
                    TaskSidebarView(selectedNote: $selectedNote)
                        .inspectorColumnWidth(min: 250, ideal: 280, max: 400)
                }
                .onAppear {
                    let manager = liveSyncManager
                    if note.googleDocId != nil {
                        manager.start(for: note)
                    }
                }
            } else {
                Text("Select a note to begin")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundColor(.secondary)
            }
        }
        .onChange(of: selectedNote) { oldVal, newVal in
            let manager = liveSyncManager
            if let n = newVal, n.googleDocId != nil {
                manager.start(for: n)
            } else {
                manager.stop()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .modifier(ContentViewSheets(showingRuleManager: $showingRuleManager, showingSettings: $showingSettings, activeConflict: $activeConflict, modelContext: modelContext, triggerSyncForNote: { triggerSync(for: $0) }))
        .modifier(DeletionConfirmationModifier(deletionManager: $deletionManager, selectedNote: $selectedNote, modelContext: modelContext))
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
        .modifier(ContentViewReceivers(
            showingRuleManager: $showingRuleManager,
            showingGlobalSearch: $showingGlobalSearch,
            showingCommandPalette: $showingCommandPalette,
            selectedNote: $selectedNote,
            deletionManager: $deletionManager,
            liveSyncManager: liveSyncManager,
            notes: notes,
            triggerSyncForNote: { note, bg in triggerSync(for: note, isBackground: bg) },
            publishDraftForNote: { note in publishDraft(note) },
            openInBrowserForNote: { note in openInBrowser(note: note) },
            syncAllNotes: { syncAllNotes() }
        ))
        .task {
            // Short delay to ensure view hierarchy is ready
            try? await Task.sleep(nanoseconds: 500_000_000)
            checkConfig()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingSettings = true }) {
                    Label("Settings", systemImage: "gear")
                }
                .help("Open App Settings")
            }
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

    private func checkConfig() {
        let id = Config.clientID
        let secret = Config.clientSecret
        let uri = Config.redirectURI
        
        print("checkConfig: id=\(id.count), secret=\(secret.count), uri=\(uri.count)")
        
        if id.isEmpty || secret.isEmpty || uri.isEmpty {
            print("checkConfig: Configuration incomplete, showing settings")
            showingSettings = true
        }
    }

    private func login() {
        guard let window = NSApp.keyWindow else { return }
        Task {
            do {
                try await AuthManager.shared.authorize(in: window)
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
        Task {
            // Use a local set or similar if we wanted to track multiple, 
            // but for now we just want to ensure we don't start overlapping global syncs.
            guard !isSyncing else { return }
            isSyncing = true
            defer { isSyncing = false }
            
            let container = modelContext.container
            await withTaskGroup(of: Void.self) { group in
                for note in notes {
                    if let _ = note.googleDocId {
                        let noteId = note.persistentModelID
                        group.addTask {
                            do {
                                // sync() is already @MainActor, so it will serialize on main 
                                // thread but allow other tasks to interleave.
                                let context = ModelContext(container)
                                try await Self.syncCoordinator.sync(noteId: noteId, in: context)
                            } catch {
                                print("Failed to sync note: \(noteId)")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func openInBrowser(note: Note? = nil) {
        let noteToOpen = note ?? selectedNote
        guard let docId = noteToOpen?.googleDocId,
              let url = URL(string: "https://docs.google.com/document/d/\(docId)") else { return }
        NSWorkspace.shared.open(url)
    }
    
    private func triggerSync(for note: Note, isBackground: Bool = false) {
        guard !isSyncing else { return }
        
        isSyncing = true
        if !isBackground {
            syncError = nil
        }
        
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
                        if !isBackground {
                            activeConflict = ConflictInfo(noteId: note.persistentModelID, local: local, remote: remote, remoteRevision: rev)
                        } else {
                            print("Background sync skipped due to conflict.")
                            NotificationCenter.default.post(name: .noRemoteEditDetected, object: nil)
                        }
                    } else {
                        if !isBackground {
                            syncError = error.localizedDescription
                        } else {
                            NotificationCenter.default.post(name: .noRemoteEditDetected, object: nil)
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if !isBackground {
                        syncError = error.localizedDescription
                    } else {
                        NotificationCenter.default.post(name: .noRemoteEditDetected, object: nil)
                    }
                    isSyncing = false
                }
            }
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
                    try? modelContext.save()
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

struct DeletionConfirmationModifier: ViewModifier {
    @Binding var deletionManager: DeletionManager
    @Binding var selectedNote: Note?
    var modelContext: ModelContext
    
    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete Note",
            isPresented: $deletionManager.showDeleteConfirmation,
            presenting: deletionManager.pendingNote
        ) { note in
            if note.googleDocId != nil && deletionManager.isOwnedByMe {
                Button("Delete Note & Trash Google Doc", role: .destructive) {
                    let isCurrentNote = (note == selectedNote)
                    Task {
                        await deletionManager.confirmDeletion(alsoTrashRemote: true, modelContext: modelContext)
                        if isCurrentNote {
                            selectedNote = nil
                        }
                    }
                }
            }
            
            Button("Delete Note Only", role: .destructive) {
                let isCurrentNote = (note == selectedNote)
                Task {
                    await deletionManager.confirmDeletion(alsoTrashRemote: false, modelContext: modelContext)
                    if isCurrentNote {
                        selectedNote = nil
                    }
                }
            }
            
            Button("Cancel", role: .cancel) {
                deletionManager.pendingNote = nil
            }
        } message: { note in
            if note.googleDocId != nil {
                if deletionManager.isOwnedByMe {
                    Text("This note is linked to a Google Doc you own. Do you want to move the Doc to Trash as well?")
                } else {
                    Text("This note is linked to a Google Doc you don't own. The Doc will not be affected.")
                }
            } else {
                Text("Are you sure you want to delete '\(note.title)'?")
            }
        }
    }
}

struct ContentViewReceivers: ViewModifier {
    @Binding var showingRuleManager: Bool
    @Binding var showingGlobalSearch: Bool
    @Binding var showingCommandPalette: Bool
    @Binding var selectedNote: Note?
    @Binding var deletionManager: DeletionManager
    var liveSyncManager: LiveSyncManager
    var notes: [Note]
    var triggerSyncForNote: (Note, Bool) -> Void
    var publishDraftForNote: (Note) -> Void
    var openInBrowserForNote: (Note?) -> Void
    var syncAllNotes: () -> Void
    
    func body(content: Content) -> some View {
        content
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
            .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedNote)) { notification in
                if let n = notification.object as? Note {
                    deletionManager.prepareDeletion(for: n)
                } else if let n = selectedNote {
                    deletionManager.prepareDeletion(for: n)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .syncNote)) { notification in
                if let n = notification.object as? Note {
                    triggerSyncForNote(n, false)
                } else if let n = selectedNote {
                    triggerSyncForNote(n, false)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openNoteInBrowser)) { notification in
                if let n = notification.object as? Note {
                    openInBrowserForNote(n)
                } else {
                    openInBrowserForNote(nil)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .publishNote)) { notification in
                if let n = notification.object as? Note {
                    publishDraftForNote(n)
                } else if let n = selectedNote {
                    publishDraftForNote(n)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .backgroundSyncRequested)) { notification in
                if let n = notification.object as? Note {
                    triggerSyncForNote(n, true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .remoteEditDetected)) { _ in
                liveSyncManager.remoteEditDetected()
            }
            .onReceive(NotificationCenter.default.publisher(for: .noRemoteEditDetected)) { _ in
                liveSyncManager.noRemoteEditDetected()
            }
    }
}

struct ContentViewSheets: ViewModifier {
    @Binding var showingRuleManager: Bool
    @Binding var showingSettings: Bool
    @Binding var activeConflict: ContentView.ConflictInfo?
    var modelContext: ModelContext
    var triggerSyncForNote: (Note) -> Void
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showingRuleManager) {
                RuleManagerView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView {
                    showingSettings = false
                }
            }
            .sheet(item: $activeConflict) { info in
                ConflictResolutionView(local: info.local, remote: info.remote) { resolvedContent in
                    resolveConflict(info, with: resolvedContent)
                } onCancel: {
                    activeConflict = nil
                }
            }
    }
    
    private func resolveConflict(_ info: ContentView.ConflictInfo, with content: String) {
        guard let note = modelContext.model(for: info.noteId) as? Note else { return }
        
        note.content = content
        note.lastSyncedRevision = info.remoteRevision
        
        do {
            try modelContext.save()
            activeConflict = nil
            triggerSyncForNote(note)
        } catch {
            print("Failed to resolve conflict: \(error.localizedDescription)")
            activeConflict = nil
        }
    }
}
