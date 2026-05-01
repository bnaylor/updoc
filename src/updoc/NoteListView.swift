import SwiftUI
import SwiftData

struct NoteListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Environment(\.modelContext) private var context
    @Binding var selectedNotes: Set<Note>
    @Binding var selectedNote: Note?
    @Environment(ThemeManager.self) private var themeManager
    @State private var isGeneralExpanded = true
    @State private var isMeetingsExpanded = true
    @State private var expandedFolders: Set<UUID> = []
    @AppStorage("expandedFoldersJSON") private var expandedFoldersJSON = "[]"
    @State private var updateTick = 0
    @State private var expandedMeetingGroups: Set<String> = []
    @AppStorage("expandedMeetingGroupsJSON") private var expandedMeetingGroupsJSON = "[]"
    @State private var showingDeleteNotesConfirmation = false
    @State private var meetingGroupsCache: [YearGroup] = []
    
    var body: some View {
        List(selection: $selectedNotes) {
            DisclosureGroup(isExpanded: $isGeneralExpanded) {
                generalNotesSection
            } label: {
                Text("GENERAL NOTES")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
            
            DisclosureGroup(isExpanded: $isMeetingsExpanded) {
                meetingNotesSection
            } label: {
                Text("MEETING NOTES")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("updoc")
        .onReceive(NotificationCenter.default.publisher(for: .deleteMultipleNotes)) { _ in
            showingDeleteNotesConfirmation = true
        }
        .onChange(of: selectedNotes) { oldVal, newVal in
            if let first = newVal.first, newVal.count == 1 {
                selectedNote = first
            } else if newVal.isEmpty {
                selectedNote = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if selectedNotes.count > 1 {
                    Button(role: .destructive) {
                        showingDeleteNotesConfirmation = true
                    } label: {
                        Label("Delete Selected", systemImage: "trash")
                    }
                }
            }
        }
        .alert("Delete Notes", isPresented: $showingDeleteNotesConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                let notesToDelete = selectedNotes
                selectedNotes.removeAll()
                selectedNote = nil
                
                for note in notesToDelete {
                    context.delete(note)
                }
                try? context.save()
                NotificationCenter.default.post(name: .treeNeedsRefresh, object: nil)
            }
        } message: {
            Text("Are you sure you want to delete \(selectedNotes.count) selected notes?")
        }
        .onReceive(NotificationCenter.default.publisher(for: .treeNeedsRefresh)) { _ in
            updateTick += 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .meetingNoteCreated)) { notification in
            if let userInfo = notification.userInfo,
               let year = userInfo["year"] as? Int,
               let month = userInfo["month"] as? Int,
               let day = userInfo["day"] as? Int {
                expandedMeetingGroups.insert("\(year)")
                expandedMeetingGroups.insert("\(year)-\(month)")
                expandedMeetingGroups.insert("\(year)-\(month)-\(day)")
            }
        }
        .onAppear {
            if let data = expandedFoldersJSON.data(using: .utf8),
               let uuids = try? JSONDecoder().decode([UUID].self, from: data) {
                expandedFolders = Set(uuids)
            }
            if let data = expandedMeetingGroupsJSON.data(using: .utf8),
               let groups = try? JSONDecoder().decode([String].self, from: data) {
                expandedMeetingGroups = Set(groups)
            }
            updateMeetingGroupsCache()
        }
        .onChange(of: expandedFolders) { oldVal, newVal in
            if let data = try? JSONEncoder().encode(Array(newVal)),
               let str = String(data: data, encoding: .utf8) {
                expandedFoldersJSON = str
            }
        }
        .onChange(of: expandedMeetingGroups) { oldVal, newVal in
            if let data = try? JSONEncoder().encode(Array(newVal)),
               let str = String(data: data, encoding: .utf8) {
                expandedMeetingGroupsJSON = str
            }
        }
        .onChange(of: notes) { _, _ in
            updateMeetingGroupsCache()
        }
    }
    
    // MARK: - General Notes Section
    @ViewBuilder
    private var generalNotesSection: some View {
        let rootFolders = folders.filter { $0.parent == nil }
        let rootNotes = notes.filter { $0.meetingID == nil && !$0.isWeeklyLog && $0.folder == nil }
        
        ForEach(rootFolders) { folder in
            FolderTreeItem(folder: folder, selectedNotes: $selectedNotes, expandedFolders: $expandedFolders, updateTick: $updateTick)
        }
        
        ForEach(rootNotes) { note in
            NoteRowView(note: note, selectedNotes: $selectedNotes)
                .tag(note)
        }
    }
    
    // MARK: - Meeting Notes Section
    @ViewBuilder
    private var meetingNotesSection: some View {
        ForEach(meetingGroupsCache) { yearGroup in
            DisclosureGroup("\(String(yearGroup.year))", isExpanded: binding(for: yearGroup.id)) {
                ForEach(yearGroup.months) { monthGroup in
                    DisclosureGroup("\(monthGroup.monthName)", isExpanded: binding(for: monthGroup.id)) {
                        ForEach(monthGroup.days) { dayGroup in
                            DisclosureGroup("Day \(dayGroup.day) (\(dayGroup.dayName))", isExpanded: binding(for: dayGroup.id)) {
                                ForEach(dayGroup.notes) { note in
                                    NoteRowView(note: note, selectedNotes: $selectedNotes)
                                        .tag(note)
                                }
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let stableId = items.first else { return false }
                                let descriptor = FetchDescriptor<Note>()
                                if let allNotes = try? context.fetch(descriptor),
                                   let draggedNote = allNotes.first(where: { $0.stableDragId == stableId }) {
                                    var comps = DateComponents()
                                    comps.year = yearGroup.year
                                    comps.month = monthGroup.month
                                    comps.day = dayGroup.day
                                    comps.hour = 12
                                    if let newDate = Calendar.current.date(from: comps) {
                                        draggedNote.createdAt = newDate
                                        draggedNote.meetingID = draggedNote.meetingID ?? "manual-meeting-\(UUID().uuidString)"
                                        draggedNote.folder = nil
                                        try? context.save()
                                        NotificationCenter.default.post(name: .treeNeedsRefresh, object: nil)
                                        return true
                                    }
                                }
                                return false
                            }
                        }
                    }
                }
            }
        }

    }
    
    private func createRootFolder() {
        let newFolder = Folder(name: "New Folder")
        context.insert(newFolder)
    }
    
    // MARK: - Chronological Groups
    struct DayGroup: Identifiable {
        let id: String
        let day: Int
        let dayName: String
        let notes: [Note]
    }
    struct MonthGroup: Identifiable {
        let id: String
        let month: Int
        let monthName: String
        let days: [DayGroup]
    }
    struct YearGroup: Identifiable {
        let id: String
        let year: Int
        let months: [MonthGroup]
    }

    private func computeMeetingGroups() -> [YearGroup] {
        let calendar = Calendar.current
        let mNotes = notes.filter { !($0.meetingID ?? "").isEmpty }
        
        let yGroup = Dictionary(grouping: mNotes) { calendar.component(.year, from: $0.createdAt) }
        
        return yGroup.map { year, yNotes in
            let mGroup = Dictionary(grouping: yNotes) { calendar.component(.month, from: $0.createdAt) }
            
            let mSorted = mGroup.map { month, mNotes in
                let dGroup = Dictionary(grouping: mNotes) { calendar.component(.day, from: $0.createdAt) }
                
                let dSorted = dGroup.map { day, dNotes in
                    // Grab the day name from the first note in the group
                    let firstDate = dNotes.first?.createdAt ?? Date()
                    let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: firstDate) - 1]
                    return DayGroup(id: "\(year)-\(month)-\(day)", day: day, dayName: dayName, notes: dNotes.sorted { $0.createdAt > $1.createdAt })
                }.sorted { $0.day > $1.day }
                
                let monthName = Calendar.current.shortMonthSymbols[month - 1]
                return MonthGroup(id: "\(year)-\(month)", month: month, monthName: monthName, days: dSorted)
            }.sorted { $0.month > $1.month }
            
            return YearGroup(id: "\(year)", year: year, months: mSorted)
        }.sorted { $0.year > $1.year }
    }
    
    private func updateMeetingGroupsCache() {
        meetingGroupsCache = computeMeetingGroups()
    }
    
    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedMeetingGroups.contains(id) },
            set: { shouldExpand in
                if shouldExpand {
                    expandedMeetingGroups.insert(id)
                } else {
                    expandedMeetingGroups.remove(id)
                }
            }
        )
    }
}

// MARK: - Components
struct FolderTreeItem: View {
    let folder: Folder
    @Binding var selectedNotes: Set<Note>
    @Binding var expandedFolders: Set<UUID>
    @Binding var updateTick: Int
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteConfirmation = false
    @State private var folderToDelete: Folder? = nil
    @State private var showingRenameAlert = false
    @State private var pendingName = ""
    @State private var showingImportAlert = false
    @State private var pendingUrl = ""
    
    var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedFolders.contains(folder.id) },
            set: {
                if $0 { expandedFolders.insert(folder.id) }
                else { expandedFolders.remove(folder.id) }
            }
        )
    }
    
    @MainActor
    private func countNotesRecursive(folder: Folder) -> Int {
        var count = folder.notes.count
        for child in folder.children {
            count += countNotesRecursive(folder: child)
        }
        return count
    }
    
    @MainActor
    private func deleteFolderRecursive(_ folder: Folder) {
        for note in folder.notes {
            self.modelContext.delete(note)
        }
        for child in folder.children {
            deleteFolderRecursive(child)
        }
        self.modelContext.delete(folder)
    }
    
    private func importNote(from urlString: String, into folder: Folder) {
        guard let docId = urlString.extractDocId() else {
            print("Failed to extract Doc ID from URL: \(urlString)")
            return
        }
        
        Task {
            do {
                let syncCoordinator = SyncCoordinator()
                let (markdown, doc) = try await syncCoordinator.gDocs.fetchDocContent(docId: docId)
                let metadata = try await syncCoordinator.gDrive.getFileMetadata(fileId: docId)
                
                let isReadOnly = !(metadata.capabilities?.canEdit ?? false)
                
                await MainActor.run {
                    let newNote = Note(
                        title: doc.title,
                        content: markdown,
                        googleDocId: docId,
                        folder: folder,
                        isReadOnly: isReadOnly
                    )
                    modelContext.insert(newNote)
                    selectedNotes = [newNote]
                    expandedFolders.insert(folder.id)
                }
            } catch {
                print("Failed to import note: \(error)")
            }
        }
    }
    

    
    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            ForEach(folder.children.sorted { $0.name < $1.name }) { childFolder in
                FolderTreeItem(folder: childFolder, selectedNotes: $selectedNotes, expandedFolders: $expandedFolders, updateTick: $updateTick)
            }
            
            ForEach(folder.notes.sorted { $0.createdAt > $1.createdAt }) { note in
                NoteRowView(note: note, selectedNotes: $selectedNotes)
                    .tag(note)
            }
        } label: {
            Label(folder.name, systemImage: "folder")
                .contextMenu {
                    Button {
                        let newNote = Note(title: "New Note", content: "", folder: folder)
                        modelContext.insert(newNote)
                        selectedNotes = [newNote]
                        expandedFolders.insert(folder.id)
                    } label: {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                    
                    Button {
                        let child = Folder(name: "New Subfolder", parent: folder)
                        modelContext.insert(child)
                        try? modelContext.save()
                        expandedFolders.insert(folder.id)
                        NotificationCenter.default.post(name: .treeNeedsRefresh, object: nil)
                    } label: {
                        Label("New Subfolder", systemImage: "folder.badge.plus")
                    }
                    
                    Button {
                        pendingUrl = ""
                        showingImportAlert = true
                    } label: {
                        Label("Import Note from Drive", systemImage: "arrow.down.doc")
                    }
                    
                    Divider()
                    
                    Button {
                        pendingName = folder.name
                        showingRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        let noteCount = countNotesRecursive(folder: folder)
                        if noteCount == 0 {
                            deleteFolderRecursive(folder)
                            try? modelContext.save()
                            NotificationCenter.default.post(name: .treeNeedsRefresh, object: nil)
                        } else {
                            folderToDelete = folder
                            showingDeleteConfirmation = true
                        }
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                }
                .alert("Rename Folder", isPresented: $showingRenameAlert) {
                    TextField("Folder Name", text: $pendingName)
                    Button("Cancel", role: .cancel) { }
                    Button("Rename") {
                        folder.name = pendingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
                .alert("Import Note from Drive", isPresented: $showingImportAlert) {
                    TextField("Google Doc URL", text: $pendingUrl)
                    Button("Cancel", role: .cancel) { }
                    Button("Import") {
                        importNote(from: pendingUrl, into: folder)
                    }
                }
        }
        .alert("Delete Folder", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let folder = folderToDelete {
                    deleteFolderRecursive(folder)
                }
            }
        } message: {
            if let folder = folderToDelete {
                let count = countNotesRecursive(folder: folder)
                Text("There are \(count) notes in this folder - delete all?")
            } else {
                Text("Are you sure you want to delete this folder?")
            }
        }
        .onTapGesture {
            NotificationCenter.default.post(name: .clearMeetingSelection, object: nil)
        }
        .dropDestination(for: String.self) { items, location in
            guard let stableId = items.first else { return false }
            let descriptor = FetchDescriptor<Note>()
            if let allNotes = try? modelContext.fetch(descriptor),
               let draggedNote = allNotes.first(where: { $0.stableDragId == stableId }) {
                draggedNote.folder = folder
                draggedNote.meetingID = nil
                try? modelContext.save()
                NotificationCenter.default.post(name: .treeNeedsRefresh, object: nil)
                return true
            }
            return false
        }
    }
}

struct NoteRowView: View {
    let note: Note
    @Binding var selectedNotes: Set<Note>
    @Environment(ThemeManager.self) private var themeManager
    
    var body: some View {
        Button {
            if NSEvent.modifierFlags.contains(.command) {
                if selectedNotes.contains(note) {
                    selectedNotes.remove(note)
                } else {
                    selectedNotes.insert(note)
                }
            } else {
                selectedNotes = [note]
            }
            NotificationCenter.default.post(name: .clearMeetingSelection, object: nil)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if note.googleDocId == nil {
                        Text("DRAFT")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.8))
                            .foregroundStyle(.white)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                }
                

            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .draggable(note.stableDragId)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            if let _ = note.googleDocId {
                Button {
                    NotificationCenter.default.post(name: .syncNote, object: note)
                } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                }
                Button {
                    NotificationCenter.default.post(name: .openNoteInBrowser, object: note)
                } label: {
                    Label("Open in Google Docs", systemImage: "arrow.up.right.square")
                }
            } else {
                Button {
                    NotificationCenter.default.post(name: .publishNote, object: note)
                } label: {
                    Label("Publish to Google Docs", systemImage: "arrow.up.doc.fill")
                }
            }
            Menu {
                Button {
                    note.themeName = nil
                } label: {
                    Text("Default")
                }
                ForEach(themeManager.allThemeNames, id: \.self) { themeName in
                    Button {
                        note.themeName = themeName
                    } label: {
                        Text(themeName)
                    }
                }
            } label: {
                Label("Theme", systemImage: "paintbrush")
            }
            Divider()
            Button(role: .destructive) {
                if selectedNotes.contains(note) && selectedNotes.count > 1 {
                    NotificationCenter.default.post(name: .deleteMultipleNotes, object: Array(selectedNotes))
                } else {
                    NotificationCenter.default.post(name: .deleteSelectedNote, object: note)
                }
            } label: {
                Label(selectedNotes.contains(note) && selectedNotes.count > 1 ? "Delete Selected Notes" : "Delete Note", systemImage: "trash")
            }
        }
    }

}
