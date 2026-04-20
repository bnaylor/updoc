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
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNote: Note?
    
    @State private var meetings: [CalendarEvent] = []
    @State private var selectedMeetingID: String? = nil
    private let templateEngine = SmartTemplateEngine()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            
            List {
                categoriesSection
                meetingsSection
            }
            .listStyle(.sidebar)
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
                meetings = []
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
                ForEach(meetings) { meeting in
                    MeetingRow(
                        meeting: meeting,
                        isSelected: selectedMeetingID == meeting.id,
                        onTap: {
                            if selectedMeetingID == meeting.id {
                                selectedMeetingID = nil
                            } else {
                                selectedMeetingID = meeting.id
                            }
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
                    self.meetings = fetchedMeetings
                    // Clear selection if the meeting is no longer in the list
                    if let currentID = self.selectedMeetingID,
                       !fetchedMeetings.contains(where: { $0.id == currentID }) {
                        self.selectedMeetingID = nil
                    }
                }
            } catch {
                print("Failed to fetch meetings: \(error)")
            }
        }
    }
    
    private func addNote() {
        if let meetingID = selectedMeetingID,
           let meeting = meetings.first(where: { $0.id == meetingID }) {
            startNote(for: meeting)
        } else {
            let newNote = Note(title: "New Note", content: "")
            modelContext.insert(newNote)
            selectedNote = newNote
        }
    }
    
    private func startNote(for meeting: CalendarEvent) {
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
    }
}
