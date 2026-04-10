import SwiftUI
import SwiftData

struct NoteListView: View {
    @Query(sort: \Note.createdAt, order: .reverse) private var notes: [Note]
    @Binding var selectedNote: Note?
    
    var body: some View {
        List(notes, selection: $selectedNote) { note in
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
                    
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
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
                    
                    Divider()
                } else {
                    Button {
                        NotificationCenter.default.post(name: .publishNote, object: note)
                    } label: {
                        Label("Publish to Google Docs", systemImage: "arrow.up.doc.fill")
                    }
                    
                    Divider()
                }
                
                Button(role: .destructive) {
                    NotificationCenter.default.post(name: .deleteSelectedNote, object: note)
                } label: {
                    Label("Delete Note", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Note List")
    }
}
