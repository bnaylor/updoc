import SwiftUI
import SwiftData

struct TaskSidebarView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActionItem.dueDate, order: .forward) private var tasks: [ActionItem]
    @Binding var selectedNote: Note?
    @State private var hideCompleted = false
    
    private var groupedTasks: [TaskSection: [ActionItem]] {
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
        
        var groups: [TaskSection: [ActionItem]] = [:]
        
        let filteredTasks = tasks.filter { task in
            if hideCompleted {
                return task.status != .done
            }
            return true
        }
        
        for task in filteredTasks {
            let section: TaskSection
            if task.status == .done {
                section = .done
            } else if let dueDate = task.dueDate {
                if dueDate < startOfToday {
                    section = .overdue
                } else if dueDate < startOfTomorrow {
                    section = .today
                } else {
                    section = .upcoming
                }
            } else {
                section = .noDueDate
            }
            
            groups[section, default: []].append(task)
        }
        
        return groups
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(TaskSection.allCases) { section in
                    if let sectionTasks = groupedTasks[section], !sectionTasks.isEmpty {
                        Section(header: Text(section.rawValue)) {
                            ForEach(sectionTasks) { task in
                                TaskRow(task: task, selectedNote: $selectedNote)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Action Items")
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        hideCompleted.toggle()
                    } label: {
                        Label(hideCompleted ? "Show Completed" : "Hide Completed", 
                              systemImage: hideCompleted ? "eye" : "eye.slash")
                    }
                    .help("Toggle completed tasks")
                }
            }
        }
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
