import SwiftUI
import SwiftData

@main
struct updocApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var themeManager = ThemeManager.shared
    
    var body: some Scene {
        WindowGroup("updoc") {
            ContentView()
                .task {
                    await AuthManager.shared.load()
                }
                .environment(themeManager)
        }
        .modelContainer(for: [Note.self, TemplateRule.self, ActionItem.self, ImageMap.self])
        .commands {
            CommandGroup(replacing: .appTermination) {
                Button("Quit updoc") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q", modifiers: .command)
            }
            
            CommandGroup(replacing: .newItem) {
                Button("New Note") {
                    NotificationCenter.default.post(name: .addNewNote, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(replacing: .pasteboard) {
                Button("Cut") { NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil) }
                    .keyboardShortcut("x", modifiers: .command)
                Button("Copy") { NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil) }
                    .keyboardShortcut("c", modifiers: .command)
                Button("Paste") { NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil) }
                    .keyboardShortcut("v", modifiers: .command)
                Button("Select All") { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
                    .keyboardShortcut("a", modifiers: .command)
            }
            
            CommandMenu("Theme") {
                ForEach(AppTheme.allCases) { theme in
                    Button(theme.rawValue) {
                        themeManager.currentTheme = theme
                    }
                }
            }
            
            CommandGroup(after: .newItem) {
                Button("Delete Note") {
                    NotificationCenter.default.post(name: .deleteSelectedNote, object: nil)
                }
                .keyboardShortcut(.delete, modifiers: .command)
                
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
                
                Button("Global Search") {
                    NotificationCenter.default.post(name: .openGlobalSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                
                Button("Command Palette") {
                    NotificationCenter.default.post(name: .openCommandPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
        
        Settings {
            SettingsView(onDone: nil)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let addNewNote = Notification.Name("addNewNote")
    static let syncAllNotes = Notification.Name("syncAllNotes")
    static let openRules = Notification.Name("openRules")
    static let openGlobalSearch = Notification.Name("openGlobalSearch")
    static let openCommandPalette = Notification.Name("openCommandPalette")
    static let focusEditor = Notification.Name("focusEditor")
    static let deleteSelectedNote = Notification.Name("deleteSelectedNote")
    static let syncNote = Notification.Name("syncNote")
    static let openNoteInBrowser = Notification.Name("openNoteInBrowser")
    static let publishNote = Notification.Name("publishNote")
    static let noteDidSyncRemotely = Notification.Name("noteDidSyncRemotely")
}
