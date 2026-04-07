import SwiftUI
import SwiftData

struct SidebarView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var templateRules: [TemplateRule]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNote: Note?
    
    @State private var meetings: [CalendarEvent] = []
    private let templateEngine = SmartTemplateEngine()
    
    var body: some View {
        List(selection: $selectedNote) {
            Section {
                if AuthManager.shared.isAuthenticated() {
                    ForEach(meetings) { meeting in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(meeting.summary)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                Text(meeting.start.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: { startNote(for: meeting) }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Start Note")
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 4)
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
            if AuthManager.shared.isAuthenticated() {
                refreshMeetings()
            }
        }
        .onChange(of: AuthManager.shared.userEmail) {
            if AuthManager.shared.isAuthenticated() {
                refreshMeetings()
            } else {
                meetings = []
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .syncAllNotes)) { _ in
            if AuthManager.shared.isAuthenticated() {
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
        if location.contains("docs.google.com/document/d/"),
           let range = location.range(of: "/d/") {
            let start = range.upperBound
            let end = location[start...].firstIndex(of: "/") ?? location.endIndex
            return String(location[start..<end])
        }
        return nil
    }
}
