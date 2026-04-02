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
    
    public init(title: String, content: String, createdAt: Date = .now, googleDocId: String? = nil, lastSyncedRevision: String? = nil, assetIds: [String] = []) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.googleDocId = googleDocId
        self.lastSyncedRevision = lastSyncedRevision
        self.assetIds = assetIds
    }
}

// Add Hashable conformance for SwiftUI navigation
extension Note: Hashable {
    public static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
