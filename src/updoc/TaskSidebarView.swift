import SwiftUI
import SwiftData

struct TaskSidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActionItem.dueDate, order: .forward) private var tasks: [ActionItem]
    @Binding var selectedNote: Note?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    TaskRow(task: task, selectedNote: $selectedNote)
                }
            }
            .navigationTitle("Action Items")
            .listStyle(.sidebar)
        }
    }
}

struct TaskRow: View {
    @Bindable var task: ActionItem
    @Binding var selectedNote: Note?
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Toggle(isOn: Binding(
                get: { task.status == .done },
                set: { task.status = $0 ? .done : .todo }
            )) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .strikethrough(task.status == .done)
                    .foregroundColor(task.status == .done ? .secondary : .primary)
                
                HStack {
                    if let dueDate = task.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(isOverdue(dueDate) && task.status != .done ? .red : .secondary)
                    }
                    
                    if let note = task.note {
                        Spacer()
                        Button {
                            selectedNote = note
                        } label: {
                            Text("from \(note.title)")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        date < Calendar.current.startOfDay(for: .now)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Note.self, ActionItem.self, configurations: config)
    
    let note = Note(title: "Sample Note", content: "Some content")
    container.mainContext.insert(note)
    
    let task = ActionItem(title: "Sample Task", dueDate: .now)
    task.note = note
    container.mainContext.insert(task)
    
    return TaskSidebarView(selectedNote: .constant(note))
        .modelContainer(container)
}
