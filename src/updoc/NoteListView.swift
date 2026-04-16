import SwiftUI
import SwiftData

struct NoteListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query(sort: \Folder.name) private var folders: [Folder]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNote: Note?
    
    @State private var isGeneralExpanded = true
    @State private var isMeetingsExpanded = true
    @State private var expandedFolders: Set<UUID> = []
    @AppStorage("expandedFoldersJSON") private var expandedFoldersJSON = "[]"
    @State private var updateTick = 0
    
    var body: some View {
        List(selection: $selectedNote) {
            DisclosureGroup(isExpanded: $isGeneralExpanded) {
                generalNotesSection
            } label: {
                Text("GENERAL NOTES")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
            
            DisclosureGroup(isExpanded: $isMeetingsExpanded) {
                meetingNotesSection
            } label: {
                Text("MEETING NOTES")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Workspace")
        .toolbar {
            Button(action: { createRootFolder() }) {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .help("Create new top-level folder")
        }
        .onReceive(NotificationCenter.default.publisher(for: .treeNeedsRefresh)) { _ in
            DispatchQueue.main.async {
                updateTick += 1
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                if let data = expandedFoldersJSON.data(using: .utf8),
                   let uuids = try? JSONDecoder().decode([UUID].self, from: data) {
                    expandedFolders = Set(uuids)
                }
            }
        }
        .onChange(of: expandedFolders) { oldVal, newVal in
            DispatchQueue.main.async {
                if let data = try? JSONEncoder().encode(Array(newVal)),
                   let str = String(data: data, encoding: .utf8) {
                    expandedFoldersJSON = str
                }
            }
        }
    }
    
    // MARK: - General Notes Section
    @ViewBuilder
    private var generalNotesSection: some View {
        let rootFolders = folders.filter { $0.parent == nil }
        let rootNotes = notes.filter { $0.meetingID == nil && !$0.isWeeklyLog && $0.folder == nil }
        
        ForEach(rootFolders) { folder in
            FolderTreeItem(folder: folder, selectedNote: $selectedNote, expandedFolders: $expandedFolders, updateTick: $updateTick)
        }
        
        ForEach(rootNotes) { note in
            NoteRowView(note: note)
                .tag(note)
        }
    }
    
    // MARK: - Meeting Notes Section
    @ViewBuilder
    private var meetingNotesSection: some View {
        ForEach(meetingGroups) { yearGroup in
            DisclosureGroup("\(String(yearGroup.year))") {
                ForEach(yearGroup.months) { monthGroup in
                    DisclosureGroup("\(monthGroup.monthName)") {
                        ForEach(monthGroup.days) { dayGroup in
                            DisclosureGroup("Day \(dayGroup.day)") {
                                ForEach(dayGroup.notes) { note in
                                    NoteRowView(note: note)
                                        .tag(note)
                                }
                            }
                            .dropDestination(for: String.self) { items, _ in
                                guard let stableId = items.first else { return false }
                                let descriptor = FetchDescriptor<Note>()
                                if let allNotes = try? modelContext.fetch(descriptor),
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
                                        try? modelContext.save()
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
        modelContext.insert(newFolder)
    }
    
    // MARK: - Chronological Groups
    struct DayGroup: Identifiable {
        let id: String
        let day: Int
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

    private var meetingGroups: [YearGroup] {
        let calendar = Calendar.current
        let mNotes = notes.filter { $0.meetingID != nil }
        
        let yGroup = Dictionary(grouping: mNotes) { calendar.component(.year, from: $0.createdAt) }
        
        return yGroup.map { year, yNotes in
            let mGroup = Dictionary(grouping: yNotes) { calendar.component(.month, from: $0.createdAt) }
            
            let mSorted = mGroup.map { month, mNotes in
                let dGroup = Dictionary(grouping: mNotes) { calendar.component(.day, from: $0.createdAt) }
                
                let dSorted = dGroup.map { day, dNotes in
                    DayGroup(id: "\(year)-\(month)-\(day)", day: day, notes: dNotes.sorted { $0.createdAt > $1.createdAt })
                }.sorted { $0.day > $1.day }
                
                let monthName = DateFormatter().shortMonthSymbols[month - 1]
                return MonthGroup(id: "\(year)-\(month)", month: month, monthName: monthName, days: dSorted)
            }.sorted { $0.month > $1.month }
            
            return YearGroup(id: "\(year)", year: year, months: mSorted)
        }.sorted { $0.year > $1.year }
    }
}

// MARK: - Components
struct FolderTreeItem: View {
    let folder: Folder
    @Binding var selectedNote: Note?
    @Binding var expandedFolders: Set<UUID>
    @Binding var updateTick: Int
    @Environment(\.modelContext) private var modelContext
    @State private var showingRenameAlert = false
    @State private var pendingName = ""
    
    var isExpanded: Binding<Bool> {
        Binding(
            get: { expandedFolders.contains(folder.id) },
            set: {
                if $0 { expandedFolders.insert(folder.id) }
                else { expandedFolders.remove(folder.id) }
            }
        )
    }
    
    var body: some View {
        DisclosureGroup(isExpanded: isExpanded) {
            ForEach(folder.children.sorted { $0.name < $1.name }) { childFolder in
                FolderTreeItem(folder: childFolder, selectedNote: $selectedNote, expandedFolders: $expandedFolders, updateTick: $updateTick)
            }
            
            ForEach(folder.notes.sorted { $0.createdAt > $1.createdAt }) { note in
                NoteRowView(note: note)
                    .tag(note)
                    .onTapGesture {
                        selectedNote = note
                        NotificationCenter.default.post(name: .clearMeetingSelection, object: nil)
                    }
            }
        } label: {
            Label(folder.name, systemImage: "folder")
                .contextMenu {
                    Button {
                        let newNote = Note(title: "New Note", content: "", folder: folder)
                        modelContext.insert(newNote)
                        selectedNote = newNote
                        expandedFolders.insert(folder.id)
                    } label: {
                        Label("New Note", systemImage: "square.and.pencil")
                    }
                    
                    Button {
                        let child = Folder(name: "New Subfolder", parent: folder)
                        modelContext.insert(child)
                        expandedFolders.insert(folder.id)
                    } label: {
                        Label("New Subfolder", systemImage: "folder.badge.plus")
                    }
                    
                    Divider()
                    
                    Button {
                        pendingName = folder.name
                        showingRenameAlert = true
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        modelContext.delete(folder)
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
    
    var body: some View {
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
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            
            Text(note.content.prefix(60))
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
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
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        note.themeName = theme.rawValue
                    } label: {
                        Text(theme.rawValue)
                    }
                }
            } label: {
                Label("Theme", systemImage: "paintbrush")
            }
            Divider()
            Button(role: .destructive) {
                NotificationCenter.default.post(name: .deleteSelectedNote, object: note)
            } label: {
                Label("Delete Note", systemImage: "trash")
            }
        }
        .draggable(note.stableDragId)
    }
}
