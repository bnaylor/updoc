import Foundation

public struct Command: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let subtitle: String?
    public let shortcut: String?
    public let action: @Sendable () -> Void
    
    public init(id: UUID = UUID(), title: String, subtitle: String? = nil, shortcut: String? = nil, action: @escaping @Sendable () -> Void) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.shortcut = shortcut
        self.action = action
    }
}

public struct CommandEngine {
    public init() {}
    
    public func search(query: String, commands: [Command], notes: [Note] = [], onNoteSelect: (@Sendable (Note) -> Void)? = nil) -> [Command] {
        if query.isEmpty { return [] }
        
        let lowerQuery = query.lowercased()
        var results: [Command] = []
        
        // Match commands
        results.append(contentsOf: commands.filter { $0.title.lowercased().contains(lowerQuery) })
        
        // Match notes (wrapped as commands)
        if let onNoteSelect = onNoteSelect {
            let noteResults = notes.filter { $0.title.lowercased().contains(lowerQuery) }.map { note in
                Command(title: "Open Note: \(note.title)", subtitle: "Note", action: {
                    onNoteSelect(note)
                })
            }
            results.append(contentsOf: noteResults)
        }
        
        return results
    }
}
