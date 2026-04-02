import SwiftUI
import SwiftData

struct SidebarView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Query private var templateRules: [TemplateRule]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNote: Note?
    
    @State private var meetings: [CalendarEvent] = []
    private let templateEngine = SmartTemplateEngine()
    @State private var showingRuleManager = false
    
    var body: some View {
        List(selection: $selectedNote) {
            Section("TODAY'S MEETINGS") {
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
            }
            
            Section("NOTES") {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        Text(note.title)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            Button("Add Note", systemImage: "plus", action: addNote)
            Button(action: { showingRuleManager = true }) {
                Label("Rules", systemImage: "gearshape")
            }
        }
        .sheet(isPresented: $showingRuleManager) {
            RuleManagerView()
        }
        .onAppear {
            refreshMeetings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .addNewNote)) { _ in
            addNote()
        }
    }
    
    private func refreshMeetings() {
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
            googleDocId: docId
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
