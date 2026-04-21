import Foundation
import SwiftData
@testable import updoc

@Model
class ActionItem {
    var title: String
    var status: ActionItemStatus
    var note: Note?
    
    init(title: String, status: ActionItemStatus = .todo) {
        self.title = title
        self.status = status
    }
}

enum ActionItemStatus: String, Codable {
    case todo
    case done
}

extension Note {
    var actionItems: [ActionItem] {
        return []
    }
    
    func updateContent(for task: ActionItem) {
        // Dummy implementation
    }
}
