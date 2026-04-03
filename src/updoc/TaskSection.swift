import Foundation

public enum TaskSection: String, CaseIterable, Identifiable {
    case overdue = "OVERDUE"
    case today = "TODAY"
    case upcoming = "UPCOMING"
    case noDueDate = "NO DUE DATE"
    case done = "DONE"
    
    public var id: String { self.rawValue }
}
