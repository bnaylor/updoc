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
    @State private var selectedNotes: Set<Note> = []
    @State private var isSyncing = false
    @State private var syncError: String?
    @State private var activeConflict: ConflictInfo?
    @State private var showingCommandPalette = false
    @State private var showingGlobalSearch = false
    @State private var showingRuleManager = false
    @State private var showingSettings = false
    @State private var showingThemeSettings = false
    @State private var selectionRange: NSRange?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showingInspector = false
    @State private var deletionManager = DeletionManager()
    @State private var liveSyncManager = LiveSyncManager()
    @FocusState private var isTitleFocused: Bool
    @State private var navigationMode: NavigationMode = .allNotes
    @State private var newTagText = ""
    @State private var contactToEdit: Contact?
    @State private var showingAddContactDialog = false
    
    @Query private var notes: [Note]
    @Environment(ThemeManager.self) private var themeManager
    @Query private var templateRules: [TemplateRule]
    private let templateEngine = SmartTemplateEngine()
    
    @State private var syncCoordinator = SyncCoordinator()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        Group {
            if navigationMode != .weeklyLog {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(navigationMode: $navigationMode, selectedNote: $selectedNote)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
                } content: {
                    if case .category(let category) = navigationMode {
                        CategoryNoteListView(category: category, selectedNote: $selectedNote)
                            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
                    } else {
                        NoteListView(selectedNotes: $selectedNotes, selectedNote: $selectedNote)
                            .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 400)
                    }
        
        } detail: {
            detailView
                }
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView(navigationMode: $navigationMode, selectedNote: $selectedNote)
                        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 250)
                } detail: {
                    WeeklyLogDashboardView(selectedNote: $selectedNote)
                }
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
        .modifier(ContentViewSheets(showingSettings: $showingSettings, showingThemeSettings: $showingThemeSettings, contactToEdit: $contactToEdit, activeConflict: $activeConflict, modelContext: modelContext, triggerSyncForNote: { triggerSync(for: $0) }))
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
            contactToEdit: $contactToEdit,
            selectedNote: $selectedNote,
            selectedNotes: $selectedNotes,
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

    
    private var appCommands: [Command] {
        var commands = [
            Command(title: "New Note", subtitle: "App", shortcut: "⌘N") {
                NotificationCenter.default.post(name: .addNewNote, object: nil)
            },
            Command(title: "Sync All Notes", subtitle: "App", shortcut: "⇧⌘S") {
                Task { @MainActor in
                    syncAllNotes()
                }
            }
        ]
        
        for themeName in themeManager.allThemeNames {
            commands.append(Command(title: "Switch to \(themeName) Theme", subtitle: "Theme") {
                Task { @MainActor in
                    themeManager.currentThemeName = themeName
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
                                try await syncCoordinator.sync(noteId: noteId, in: context)
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
        
        let noteId = note.persistentModelID
        Task {
            do {
                try await syncCoordinator.sync(noteId: noteId, in: modelContext)
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
                let rootFolder = try await syncCoordinator.gDrive.getOrCreateFolder(named: "updoc")
                let leafFolderId: String
                
                if note.meetingID != nil {
                    let meetingsFolderId = try await syncCoordinator.gDrive.getOrCreateFolder(named: "Meetings", parentId: rootFolder)
                    
                    let calendar = Calendar.current
                    let year = calendar.component(.year, from: note.createdAt)
                    let month = calendar.component(.month, from: note.createdAt)
                    let day = calendar.component(.day, from: note.createdAt)
                    
                    let yearFolderId = try await syncCoordinator.gDrive.getOrCreateFolder(named: String(year), parentId: meetingsFolderId)
                    let monthFolderId = try await syncCoordinator.gDrive.getOrCreateFolder(named: String(format: "%02d", month), parentId: yearFolderId)
                    leafFolderId = try await syncCoordinator.gDrive.getOrCreateFolder(named: String(format: "%02d", day), parentId: monthFolderId)
                } else {
                    let generalFolderId = try await syncCoordinator.gDrive.getOrCreateFolder(named: "General", parentId: rootFolder)
                    
                    var currentFolderId = generalFolderId
                    var folderPath: [String] = []
                    var currentFolder = note.folder
                    while let folder = currentFolder {
                        folderPath.insert(folder.name, at: 0)
                        currentFolder = folder.parent
                    }
                    
                    for folderName in folderPath {
                        currentFolderId = try await syncCoordinator.gDrive.getOrCreateFolder(named: folderName, parentId: currentFolderId)
                    }
                    leafFolderId = currentFolderId
                }
                
                // 2. Create Doc
                let docId = try await syncCoordinator.gDrive.createDoc(name: note.title, parentId: leafFolderId)
                
                // 3. Link and Initial Sync
                await MainActor.run {
                    note.googleDocId = docId
                    try? modelContext.save()
                }
                
                try await syncCoordinator.sync(noteId: note.persistentModelID, in: modelContext)
                
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
    
    private var detailView: some View {
        Group {
            if let note = selectedNote {
                makeNoteDetailView(note: note)
            } else {
                Text("Select a note to begin")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private func makeNoteDetailView(note: Note) -> some View {
        NoteDetailView(
            note: note,
            rules: templateRules,
            isTitleFocused: $isTitleFocused,
            isSyncing: isSyncing,
            liveSyncManager: liveSyncManager,
            syncError: syncError,
            newTagText: $newTagText,
            selectionRange: $selectionRange,
            showingInspector: $showingInspector,
            triggerSync: { self.triggerSync(for: $0) },
            openInBrowser: { self.openInBrowser(note: note) },
            publishDraft: { self.publishDraft($0) }
        )
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
    @Binding var contactToEdit: Contact?
    @Binding var selectedNote: Note?
    @Binding var selectedNotes: Set<Note>
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
            .onReceive(NotificationCenter.default.publisher(for: .openAddContactDialog)) { notification in
                if let contact = notification.object as? Contact {
                    contactToEdit = contact
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deleteSelectedNote)) { notification in
                if let n = notification.object as? Note {
                    deletionManager.prepareDeletion(for: n)
                } else if self.selectedNotes.count > 1 {
                    NotificationCenter.default.post(name: .deleteMultipleNotes, object: nil)
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
    @Binding var showingSettings: Bool
    @Binding var showingThemeSettings: Bool
    @Binding var contactToEdit: Contact?
    @Binding var activeConflict: ContentView.ConflictInfo?
    var modelContext: ModelContext
    var triggerSyncForNote: (Note) -> Void
    
    @Environment(ThemeManager.self) private var themeManager
    
    func body(content: Content) -> some View {
        content


            .sheet(isPresented: $showingSettings) {
                SettingsView(onAddRule: {
                    print("onAddRule called in ContentView")
                    let newRule = TemplateRule(attribute: .title, pattern: "1:1", templateContent: "# 1:1 w/ {{title}}\n\n## Discussion\n- ")
                    modelContext.insert(newRule)
                    do {
                        try modelContext.save()
                        print("Rule saved successfully in ContentView")
                    } catch {
                        print("Failed to save rule in ContentView: \(error.localizedDescription)")
                    }
                }, onAddFilterRule: {
                    print("onAddFilterRule called in ContentView")
                    let newRule = MeetingFilterRule(titlePattern: "Focus Time")
                    modelContext.insert(newRule)
                    do {
                        try modelContext.save()
                        print("Filter rule saved successfully in ContentView")
                    } catch {
                        print("Failed to save filter rule in ContentView: \(error.localizedDescription)")
                    }
                }, onDone: {
                    showingSettings = false
                })
                .environment(themeManager)
                .modelContainer(modelContext.container)
            }
            .sheet(item: $activeConflict) { info in
                ConflictResolutionView(local: info.local, remote: info.remote) { resolvedContent in
                    resolveConflict(info, with: resolvedContent)
                } onCancel: {
                    activeConflict = nil
                }
            }
            .sheet(item: $contactToEdit) { contact in
                AddContactView(contact: contact)
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
