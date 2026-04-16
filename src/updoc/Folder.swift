import Foundation
import SwiftData

@Model
public class Folder {
    public var id: UUID = UUID()
    public var name: String
    public var createdAt: Date = Date.now
    
    @Relationship(deleteRule: .nullify, inverse: \Folder.children)
    public var parent: Folder?
    
    public var children: [Folder] = []
    
    @Relationship(deleteRule: .nullify)
    public var notes: [Note] = []
    
    public init(name: String, parent: Folder? = nil) {
        self.name = name
        self.parent = parent
    }
}
