import SwiftUI
import SwiftData

public enum NavigationMode: Equatable, Hashable {
    case allNotes
    case weeklyLog
    case category(String)
}

struct SidebarView: View {
    @Binding var navigationMode: NavigationMode
    @Query private var templateRules: [TemplateRule]
    @Query private var allNotes: [Note]
    @Query private var filterRules: [MeetingFilterRule]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNote: Note?
    
    @State private var allFetchedMeetings: [CalendarEvent] = []
    
    private var filteredMeetings: [CalendarEvent] {
        allFetchedMeetings.filter { meeting in
            !shouldFilter(meeting)
        }
    }
    @State private var selectedMeetingID: String? = nil
    @State private var showingAttachmentAlert = false
    @State private var pendingAttachment: CalendarAttachment? = nil
    @State private var pendingMeeting: CalendarEvent? = nil
    private let templateEngine = SmartTemplateEngine()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            
            List {
                categoriesSection
                meetingsSection
            }
            .listStyle(.sidebar)
            .alert("Linked Note Found", isPresented: $showingAttachmentAlert) {
                Button("Use Existing") {
                    if let attachment = pendingAttachment, let meeting = pendingMeeting {
                        importNote(from: attachment.fileUrl, for: meeting)
                    }
                }
                Button("Create My Own") {
                    if let meeting = pendingMeeting {
                        createBlankNote(for: meeting)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("There is already a note linked to this meeting. Do you want to use it, or create your own?")
            }
        }
        .navigationTitle("updoc")
        .onAppear {
            DispatchQueue.main.async {
                if AuthManager.shared.isAuthenticated() {
                    refreshMeetings()
                }
            }
        }
        .onChange(of: AuthManager.shared.userEmail) {
            if AuthManager.shared.isAuthenticated() {
                refreshMeetings()
            } else {
                allFetchedMeetings = []
                selectedMeetingID = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncAllNotes)) { _ in
            if AuthManager.shared.isAuthenticated() {
                refreshMeetings()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearMeetingSelection)) { _ in
            selectedMeetingID = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewNote)) { _ in
            addNote()
        }
    }
    
    private var uniqueCategories: [String] {
        Array(Set(allNotes.flatMap { $0.categories })).sorted()
    }
    
    private var categoriesSection: some View {
        Section("CATEGORIES") {
            Button {
                navigationMode = .allNotes
            } label: {
                Label("All Notes", systemImage: "note.text")
                    .foregroundColor(navigationMode == .allNotes ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
            
            Button {
                navigationMode = .weeklyLog
            } label: {
                Label("Weekly Snippets", systemImage: "calendar.day.timeline.left")
                    .foregroundColor(navigationMode == .weeklyLog ? .accentColor : .primary)
            }
            .buttonStyle(.plain)
            
            if !uniqueCategories.isEmpty {
                Divider()
                ForEach(uniqueCategories, id: \.self) { category in
                    Button {
                        navigationMode = .category(category)
                    } label: {
                        Label(category, systemImage: "number")
                            .foregroundColor(navigationMode == .category(category) ? .accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var meetingsSection: some View {
        Section {
            if AuthManager.shared.isAuthenticated() {
                ForEach(filteredMeetings) { meeting in
                    MeetingRow(
                        meeting: meeting,
                        isSelected: selectedMeetingID == meeting.id,
                        onTap: {
                            if selectedMeetingID == meeting.id {
                                selectedMeetingID = nil
                            } else {
                                selectedMeetingID = meeting.id
                            }
                        },
                        onCreateNote: {
                            startNote(for: meeting)
                        },
                        onFilterMeeting: {
                            filterMeeting(meeting)
                        }
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Log in to see meetings")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button(action: login) {
                        Text("Log in with Google")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text("TODAY'S MEETINGS")
                Spacer()
                if AuthManager.shared.isAuthenticated() {
                    Button(action: refreshMeetings) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: { addNote() }) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("New Note")
            
            Button(action: { createRootFolder() }) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("New Folder")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func createRootFolder() {
        let newFolder = Folder(name: "New Folder")
        modelContext.insert(newFolder)
        NotificationCenter.default.post(name: .treeNeedsRefresh, object: nil)
    }
    
    private func login() {
        guard let window = NSApp.keyWindow else { return }
        Task {
            do {
                try await AuthManager.shared.authorize(in: window)
            } catch {
                print("Sidebar login failed: \(error)")
            }
        }
    }
    
    private func refreshMeetings() {
        guard AuthManager.shared.isAuthenticated() else { return }
        Task {
            do {
                let fetchedMeetings = try await GCalendarService.shared.fetchTodaysEvents()
                await MainActor.run {
                    self.allFetchedMeetings = fetchedMeetings
                    // Clear selection if the meeting is no longer in the list
                    if let currentID = self.selectedMeetingID,
                       !self.filteredMeetings.contains(where: { $0.id == currentID }) {
                        self.selectedMeetingID = nil
                    }
                }
            } catch {
                print("Failed to fetch meetings: \(error)")
            }
        }
    }
    
    private func shouldFilter(_ meeting: CalendarEvent) -> Bool {
        for rule in filterRules {
            var matchesAll = true
            
            if let titlePat = rule.titlePattern, !titlePat.isEmpty {
                if !meeting.summary.localizedCaseInsensitiveContains(titlePat) {
                    matchesAll = false
                }
            }
            
            if let descPat = rule.descriptionPattern, !descPat.isEmpty {
                if let desc = meeting.description, desc.localizedCaseInsensitiveContains(descPat) {
                    // Matches
                } else {
                    matchesAll = false
                }
            }
            
            if let partPat = rule.participantPattern, !partPat.isEmpty {
                if !meeting.attendees.contains(where: { $0.localizedCaseInsensitiveContains(partPat) }) {
                    matchesAll = false
                }
            }
            
            if let typePat = rule.eventType, !typePat.isEmpty {
                if let type = meeting.eventType, type.localizedCaseInsensitiveContains(typePat) {
                    // Matches
                } else {
                    matchesAll = false
                }
            }
            
            if let isAllDay = rule.isAllDay {
                if meeting.isAllDay != isAllDay {
                    matchesAll = false
                }
            }
            
            if matchesAll {
                return true // Filter it!
            }
        }
        return false // Keep it!
    }
    
    private func filterMeeting(_ meeting: CalendarEvent) {
        let newRule = MeetingFilterRule(
            titlePattern: meeting.summary,
            isAllDay: meeting.isAllDay,
            eventType: meeting.eventType
        )
        modelContext.insert(newRule)
        do {
            try modelContext.save()
            print("Created filter rule for: \(meeting.summary)")
            refreshMeetings()
        } catch {
            print("Failed to save filter rule: \(error.localizedDescription)")
        }
    }
    
    private func addNote() {
        if let meetingID = selectedMeetingID,
           let meeting = allFetchedMeetings.first(where: { $0.id == meetingID }) {
            startNote(for: meeting)
        } else {
            let newNote = Note(title: "New Note", content: "")
            modelContext.insert(newNote)
            selectedNote = newNote
        }
    }
    
    private func startNote(for meeting: CalendarEvent) {
        if let attachment = meeting.attachments.first {
            pendingAttachment = attachment
            pendingMeeting = meeting
            showingAttachmentAlert = true
            return
        }
        
        createBlankNote(for: meeting)
    }
    
    private func createBlankNote(for meeting: CalendarEvent) {
        let input = TemplateInput(
            title: meeting.summary,
            attendees: meeting.attendees,
            date: meeting.start,
            location: meeting.location,
            description: meeting.description
        )
        let resolved = templateEngine.resolveTemplate(for: input, rules: templateRules)
        
        let docId = extractDocId(from: meeting.location)
        
        let newNote = Note(
            title: meeting.summary,
            content: resolved.content,
            googleDocId: docId,
            meetingID: meeting.id,
            themeName: resolved.themeName
        )
        
        modelContext.insert(newNote)
        selectedNote = newNote
        
        let calendar = Calendar.current
        let year = calendar.component(.year, from: meeting.start)
        let month = calendar.component(.month, from: meeting.start)
        let day = calendar.component(.day, from: meeting.start)
        
        NotificationCenter.default.post(name: .meetingNoteCreated, object: nil, userInfo: ["year": year, "month": month, "day": day])
    }
    
    private func importNote(from urlString: String, for meeting: CalendarEvent) {
        guard let docId = extractDocId(from: urlString) else { return }
        
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
                        meetingID: meeting.id,
                        isReadOnly: isReadOnly
                    )
                    modelContext.insert(newNote)
                    selectedNote = newNote
                    
                    let calendar = Calendar.current
                    let year = calendar.component(.year, from: meeting.start)
                    let month = calendar.component(.month, from: meeting.start)
                    let day = calendar.component(.day, from: meeting.start)
                    
                    NotificationCenter.default.post(name: .meetingNoteCreated, object: nil, userInfo: ["year": year, "month": month, "day": day])
                }
            } catch {
                print("Failed to import note: \(error)")
            }
        }
    }
    
    private func extractDocId(from location: String?) -> String? {
        guard let location = location else { return nil }
        if location.contains("docs.google.com/document/d/"),
           let range = location.range(of: "/d/") {
            let start = range.upperBound
            let end = location[start...].firstIndex(of: "/") ?? location.endIndex
            return String(location[start..<end])
        }
        return nil
    }
}

struct MeetingRow: View {
    let meeting: CalendarEvent
    let isSelected: Bool
    let onTap: () -> Void
    let onCreateNote: () -> Void
    let onFilterMeeting: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(meeting.summary)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .bold : .semibold)
                    .lineLimit(1)
                
                Text(meeting.start.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(action: onCreateNote) {
                Label("New Note", systemImage: "note.text.badge.plus")
            }
            
            Button(action: onFilterMeeting) {
                Label("Filter Meeting", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }
}
