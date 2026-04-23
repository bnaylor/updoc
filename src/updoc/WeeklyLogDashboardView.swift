import SwiftUI
import SwiftData

struct WeeklyLogDashboardView: View {
    @Query private var notes: [Note]
    @Environment(\.modelContext) private var modelContext
    @Binding var selectedNote: Note?
    
    @State private var currentWeekDate = Date()
    @State private var selectionRange: NSRange?
    @Environment(ThemeManager.self) private var themeManager
    
    private var weekString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: currentWeekDate) else { return "" }
        return "\(formatter.string(from: interval.start)) – \(formatter.string(from: interval.end.addingTimeInterval(-1)))"
    }
    
    private var currentWeeklyLogId: String {
        let calendar = Calendar.current
        let year = calendar.component(.yearForWeekOfYear, from: currentWeekDate)
        let week = calendar.component(.weekOfYear, from: currentWeekDate)
        return "\(year)-W\(String(format: "%02d", week))"
    }
    
    private var currentNote: Note? {
        notes.first { $0.isWeeklyLog && $0.weeklyLogId == currentWeeklyLogId }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Dashboard Pagination Header
            HStack {
                Button {
                    changeWeek(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                
                Text(weekString)
                    .font(.headline)
                    .padding(.horizontal, 8)
                
                Button {
                    changeWeek(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    currentWeekDate = Date()
                } label: {
                    Text("Today")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            if let note = currentNote {
                EditorView(text: Binding(
                    get: { note.content },
                    set: { note.content = $0 }
                ), assetIds: Binding(
                    get: { note.assetIds },
                    set: { note.assetIds = $0 }
                ), selectionRange: $selectionRange, theme: themeManager.themeName(for: note), isReadOnly: note.isReadOnly, modelContainer: modelContext.container)
                .onAppear {
                    NotificationCenter.default.post(name: .focusEditor, object: nil)
                }
                .onChange(of: note.id) {
                    NotificationCenter.default.post(name: .focusEditor, object: nil)
                }
            } else {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No snippet log found for this week.")
                        .font(.headline)
                    Button("Start Weekly Log") {
                        createWeeklyLog()
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        .navigationTitle("Snippets: \(weekString)")
        .onAppear {
            syncSelection()
        }
        .onChange(of: currentWeeklyLogId) {
            syncSelection()
        }
    }
    
    private func changeWeek(by weeks: Int) {
        if let newDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: currentWeekDate) {
            currentWeekDate = newDate
        }
    }
    
    private func syncSelection() {
        if let note = currentNote {
            selectedNote = note
        } else {
            selectedNote = nil
        }
    }
    
    private func createWeeklyLog() {
        let title = "Weekly Log: \(weekString)"
        let newNote = Note(title: title, content: "# Snippets\n\n- ", isWeeklyLog: true, weeklyLogId: currentWeeklyLogId)
        modelContext.insert(newNote)
        selectedNote = newNote
    }
}
