import Foundation
import SwiftData

@Model
public class TemplateRule {
    @Attribute(.unique) public var id: UUID
    public var attribute: String // "Title", "Participant"
    public var pattern: String
    public var templateContent: String
    
    public init(attribute: String, pattern: String, templateContent: String) {
        self.id = UUID()
        self.attribute = attribute
        self.pattern = pattern
        self.templateContent = templateContent
    }
}
