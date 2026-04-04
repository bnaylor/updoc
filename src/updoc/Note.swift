import Foundation
import SwiftData

@Model
public class Note {
    public var title: String
    public var content: String
    public var createdAt: Date
    public var googleDocId: String?
    public var lastSyncedRevision: String?
    public var assetIds: [String] = []
    public var meetingID: String?
    
    @Relationship(deleteRule: .cascade)
    public var actionItems: [ActionItem] = []
    
    public init(title: String, content: String, createdAt: Date = .now, googleDocId: String? = nil, lastSyncedRevision: String? = nil, assetIds: [String] = [], meetingID: String? = nil, actionItems: [ActionItem] = []) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.googleDocId = googleDocId
        self.lastSyncedRevision = lastSyncedRevision
        self.assetIds = assetIds
        self.meetingID = meetingID
        self.actionItems = actionItems
    }
    
    /// Updates the note content to reflect the current status of an ActionItem.
    /// Finds the corresponding markdown task (e.g., `[ ] Task Name`) and updates its status marker.
    public func updateContent(for actionItem: ActionItem) {
        let lines = content.components(separatedBy: .newlines)
        var updatedLines = [String]()
        
        let marker = actionItem.status == .done ? "x" : " "
        let escapedTitle = NSRegularExpression.escapedPattern(for: actionItem.title)
        
        // Pattern to match markdown task items:
        // - Group 1: Leading list marker (*, -, +, or 1.) and spacing
        // - Group 2: Current checkbox [ ] or [x] or [X]
        // - Group 3: Task title matching actionItem.title (allowing for trailing whitespace)
        let pattern = "^(\\s*[*+\\-]\\s+|\\s*\\d+\\.\\s*)\\[([ xX])\\]\\s+(\(escapedTitle))\\s*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return
        }
        
        var found = false
        for line in lines {
            let range = NSRange(location: 0, length: line.utf16.count)
            if let match = regex.firstMatch(in: line, options: [], range: range) {
                // If there are multiple tasks with the same name, this logic currently updates all of them
                // which matches actionItem.title. If we wanted more precision, we'd need line numbers.
                let markerRange = match.range(at: 2)
                if let swiftRange = Range(markerRange, in: line) {
                    var updatedLine = line
                    updatedLine.replaceSubrange(swiftRange, with: marker)
                    updatedLines.append(updatedLine)
                    found = true
                    continue
                }
            }
            updatedLines.append(line)
        }
        
        if found {
            self.content = updatedLines.joined(separator: "\n")
        }
    }
}

// Add Hashable and Sendable conformance for SwiftUI navigation and concurrency
// Note: @Model macro may provide Sendable in some contexts, but it's explicitly required for our Search/Command engines.
extension Note: Hashable, @unchecked Sendable {
    public static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
