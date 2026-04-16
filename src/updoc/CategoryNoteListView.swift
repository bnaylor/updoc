import SwiftUI
import SwiftData

struct CategoryNoteListView: View {
    let category: String
    @Query private var allNotes: [Note]
    @Binding var selectedNote: Note?
    
    private var matchingNotes: [Note] {
        allNotes.filter { $0.categories.contains(category) }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        List(matchingNotes, selection: $selectedNote) { note in
            NavigationLink(value: note) {
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
                    
                    Text(note.content.prefix(100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Tag: #\(category)")
    }
}
