import SwiftUI
import SwiftData

@main
struct updocApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var themeManager = ThemeManager.shared
    
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: Note.self, Folder.self, TemplateRule.self, ImageMap.self, MeetingFilterRule.self, Contact.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup("updoc") {
            ContentView()
                .task {
                    await AuthManager.shared.load()
                }
                .task {
                    // Run once on first launch after upgrade
                    let ctx = container.mainContext
                    await MainActor.run {
                        AppMigrationManager.runIfNeeded(context: ctx)
                    }
                }
                .environment(themeManager)
        }
        .modelContainer(container)
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
            
            CommandGroup(replacing: .importExport) {
                Button("Import Notes from JSON...") {
                    NotificationCenter.default.post(name: .triggerImport, object: nil)
                }
                Button("Export Notes to Markdown...") {
                    NotificationCenter.default.post(name: .triggerExport, object: nil)
                }
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
                ForEach(themeManager.allThemeNames, id: \.self) { themeName in
                    Button(themeName) {
                        themeManager.currentThemeName = themeName
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
            SettingsView(onAddRule: {
                print("onAddRule called in app Settings")
                let context = ModelContext(container)
                let newRule = TemplateRule(attribute: .title, pattern: "1:1", templateContent: "# 1:1 w/ {{title}}\n\n## Discussion\n- ")
                context.insert(newRule)
                do {
                    try context.save()
                    print("Rule saved successfully in app Settings")
                } catch {
                    print("Failed to save rule in app Settings: \(error.localizedDescription)")
                }
            }, onAddFilterRule: {
                print("onAddFilterRule called in app Settings")
                let context = ModelContext(container)
                let newRule = MeetingFilterRule(titlePattern: "Focus Time")
                context.insert(newRule)
                do {
                    try context.save()
                    print("Filter rule saved successfully in app Settings")
                } catch {
                    print("Failed to save filter rule in app Settings: \(error.localizedDescription)")
                }
            }, onDone: nil)
            .environment(themeManager)
            .modelContainer(container)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = Bundle.main.url(forResource: "updoc", withExtension: "jpeg"),
           let image = NSImage(contentsOfFile: url.path) {
            NSApp.applicationIconImage = image
        }
    }
    
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
    static let deleteMultipleNotes = Notification.Name("deleteMultipleNotes")
    static let syncNote = Notification.Name("syncNote")
    static let openNoteInBrowser = Notification.Name("openNoteInBrowser")
    static let publishNote = Notification.Name("publishNote")
    static let noteDidSyncRemotely = Notification.Name("noteDidSyncRemotely")
    static let backgroundSyncRequested = Notification.Name("backgroundSyncRequested")
    static let remoteEditDetected = Notification.Name("remoteEditDetected")
    static let noRemoteEditDetected = Notification.Name("noRemoteEditDetected")
    static let clearMeetingSelection = Notification.Name("clearMeetingSelection")
    static let triggerImport = Notification.Name("triggerImport")
    static let triggerExport = Notification.Name("triggerExport")
    static let treeNeedsRefresh = Notification.Name("treeNeedsRefresh")
    static let meetingNoteCreated = Notification.Name("meetingNoteCreated")
    static let openAddContactDialog = Notification.Name("openAddContactDialog")
}
