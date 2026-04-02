import SwiftUI
import SwiftData

struct SidebarView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNote: Note?
    
    var body: some View {
        List(selection: $selectedNote) {
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
        }
    }
    
    private func addNote() {
        let newNote = Note(title: "New Note", content: "")
        modelContext.insert(newNote)
        selectedNote = newNote
    }
}
