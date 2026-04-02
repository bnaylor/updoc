import Foundation
import SwiftData

@Model
class Note {
    var title: String
    var content: String
    var createdAt: Date
    
    init(title: String, content: String, createdAt: Date = .now) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
    }
}

// Add Hashable conformance for SwiftUI navigation
extension Note: Hashable {
    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
