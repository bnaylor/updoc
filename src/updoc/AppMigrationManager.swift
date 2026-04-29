import Foundation
import SwiftData

/// Runs one-time content migrations keyed by an integer version stored in UserDefaults.
/// Each migration version runs exactly once, in order, on first launch after an upgrade.
@MainActor
struct AppMigrationManager {
    static let currentVersion = 1
    private static let versionKey = "appMigrationVersion"

    /// Call once from the app entry point after the ModelContext is available.
    static func runIfNeeded(context: ModelContext) {
        let last = UserDefaults.standard.integer(forKey: versionKey)
        guard last < currentVersion else { return }

        if last < 1 { migrateChecklistSyntax(context: context) }

        UserDefaults.standard.set(currentVersion, forKey: versionKey)
    }

    private static func migrateChecklistSyntax(context: ModelContext) {
        let descriptor = FetchDescriptor<Note>()
        guard let notes = try? context.fetch(descriptor) else { return }
        var changed = false
        for note in notes {
            let migrated = migrateContent(note.content)
            if migrated != note.content {
                note.content = migrated
                changed = true
            }
        }
        if changed { try? context.save() }
    }

    /// Pure function — converts bare `[ ] text` / `[x] text` lines to GFM `- [ ] text` / `- [x] text`.
    /// Lines that already have a list marker (`-`, `*`, `+`) before the checkbox are left unchanged.
    nonisolated static func migrateContent(_ content: String) -> String {
        let lines = content.components(separatedBy: "\n")
        return lines.map { line -> String in
            let whitespace = String(line.prefix(while: { $0 == " " || $0 == "\t" }))
            let rest = String(line.dropFirst(whitespace.count))

            // Already has a recognised list marker — leave alone
            if rest.hasPrefix("- [") || rest.hasPrefix("* [") || rest.hasPrefix("+ [") {
                return line
            }

            if rest.hasPrefix("[ ] ") {
                return whitespace + "- [ ] " + rest.dropFirst(4)
            }
            if rest == "[ ]" {
                return whitespace + "- [ ]"
            }
            if rest.hasPrefix("[x] ") || rest.hasPrefix("[X] ") {
                return whitespace + "- [x] " + rest.dropFirst(4)
            }
            if rest == "[x]" || rest == "[X]" {
                return whitespace + "- [x]"
            }

            return line
        }.joined(separator: "\n")
    }
}
