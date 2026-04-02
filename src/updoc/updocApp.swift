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
        .modelContainer(for: [Note.self, TemplateRule.self])
    }
}
