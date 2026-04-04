import Foundation
import SwiftData

@Model
public class ActionItem {
    public var title: String
    public var assignee: String?
    public var dueDate: Date?
    public var status: ActionItemStatus
    public var createdAt: Date
    public var note: Note?
    
    public init(title: String, assignee: String? = nil, dueDate: Date? = nil, status: ActionItemStatus = .todo, createdAt: Date = .now) {
        self.title = title
        self.assignee = assignee
        self.dueDate = dueDate
        self.status = status
        self.createdAt = createdAt
    }
    
    public var isOverdue: Bool {
        guard let dueDate = dueDate, status != .done else { return false }
        return dueDate < Calendar.current.startOfDay(for: .now)
    }
}

public enum ActionItemStatus: String, Codable, CaseIterable {
    case todo = "TODO"
    case inProgress = "IN PROGRESS"
    case done = "DONE"
    case blocked = "BLOCKED"
}
