import SwiftUI
import SwiftData

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
                    .foregroundStyle(task.status == .done ? .secondary : .primary)
                
                HStack {
                    if let dueDate = task.dueDate {
                        Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }
                    
                    if let note = task.note {
                        Spacer()
                        Text(note.title)
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if let note = task.note {
                    selectedNote = note
                }
            }
        }
        .padding(.vertical, 4)
    }
}
