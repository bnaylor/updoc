import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedNote: Note?
    
    var body: some View {
        NavigationSplitView {
            SidebarView(selectedNote: $selectedNote)
        } detail: {
            if let note = selectedNote {
                EditorView(text: Binding(
                    get: { note.content },
                    set: { note.content = $0 }
                ))
                .navigationTitle(note.title)
            } else {
                Text("Select a note to begin")
                    .foregroundColor(.secondary)
            }
        }
    }
}
