import SwiftUI
import SwiftData

@main
struct updocApp: App {
    @State private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(themeManager)
        }
        .modelContainer(for: [Note.self, TemplateRule.self, ActionItem.self])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .addNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandMenu("Theme") {
                ForEach(AppTheme.allCases) { theme in
                    Button(theme.rawValue) {
                        themeManager.currentTheme = theme
                    }
                }
            }
            
            CommandGroup(after: .newItem) {
                Button("Sync All Notes") {
                    NotificationCenter.default.post(name: .syncAllNotes, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
            
            CommandGroup(after: .toolbar) {
                Button("Open Template Rules") {
                    NotificationCenter.default.post(name: .openRules, object: nil)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}

extension Notification.Name {
    static let addNewNote = Notification.Name("addNewNote")
    static let syncAllNotes = Notification.Name("syncAllNotes")
    static let openRules = Notification.Name("openRules")
}
