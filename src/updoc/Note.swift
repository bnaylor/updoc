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
