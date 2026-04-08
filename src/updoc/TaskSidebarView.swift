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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Action Items")
                    .font(.headline)
                Spacer()
                
                // Toggle completed tasks
                Button {
                    hideCompleted.toggle()
                } label: {
                    Image(systemName: hideCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundColor(hideCompleted ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(hideCompleted ? "Show Completed" : "Hide Completed")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
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
            .listStyle(.sidebar)
        }
    }
}
