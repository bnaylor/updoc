import SwiftUI
import SwiftData

struct SidebarView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var templateRules: [TemplateRule]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNote: Note?
    
    @State private var meetings: [CalendarEvent] = []
    @State private var isAuthenticated = false
    private let templateEngine = SmartTemplateEngine()
    
    var body: some View {
        List(selection: $selectedNote) {
            Section {
                if isAuthenticated {
                    ForEach(meetings) { meeting in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(meeting.summary)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(meeting.start.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: { startNote(for: meeting) }) {
                                Text("Start Note")
                                    .font(.caption)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
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
                    if isAuthenticated {
                        Button(action: refreshMeetings) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Section("NOTES") {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        HStack {
                            Text(note.title)
                            if note.googleDocId == nil {
                                Spacer()
                                Text("DRAFT")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: addNote) {
                    Label("Add Note", systemImage: "plus")
                }
            }
        }
        .onAppear {
            isAuthenticated = AuthManager.shared.isAuthenticated()
            if isAuthenticated {
                refreshMeetings()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncAllNotes)) { _ in
            isAuthenticated = AuthManager.shared.isAuthenticated()
            if isAuthenticated {
                refreshMeetings()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewNote)) { _ in
            addNote()
        }
    }
    
    private func login() {
        guard let window = NSApp.keyWindow else { return }
        Task {
            do {
                try await AuthManager.shared.authorize(in: window)
                await MainActor.run {
                    self.isAuthenticated = AuthManager.shared.isAuthenticated()
                    if self.isAuthenticated {
                        refreshMeetings()
                    }
                }
            } catch {
                print("Login failed: \(error)")
            }
        }
    }
    
    private func refreshMeetings() {
        guard isAuthenticated else { return }
        Task {
            do {
                let fetchedMeetings = try await GCalendarService.shared.fetchTodaysEvents()
                await MainActor.run {
                    self.meetings = fetchedMeetings
                }
            } catch {
                print("Failed to fetch meetings: \(error)")
            }
        }
    }
    
    private func addNote() {
        let newNote = Note(title: "New Note", content: "")
        modelContext.insert(newNote)
        selectedNote = newNote
    }
    
    private func startNote(for meeting: CalendarEvent) {
        let content = templateEngine.resolveTemplate(for: meeting, rules: templateRules)
        
        // Extract Doc ID from location if it's a Google Doc
        let docId = extractDocId(from: meeting.location)
        
        let newNote = Note(
            title: meeting.summary,
            content: content,
            googleDocId: docId,
            meetingID: meeting.id
        )
        
        modelContext.insert(newNote)
        selectedNote = newNote
    }
    
    private func extractDocId(from location: String?) -> String? {
        guard let location = location else { return nil }
        // Simple regex or check for Google Doc patterns
        if location.contains("docs.google.com/document/d/"),
           let range = location.range(of: "/d/") {
            let start = range.upperBound
            let end = location[start...].firstIndex(of: "/") ?? location.endIndex
            return String(location[start..<end])
        }
        return nil
    }
}
