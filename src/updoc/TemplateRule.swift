import Foundation
import SwiftData

public enum RuleAttribute: String, Codable, CaseIterable {
    case title = "Title"
    case participant = "Participant"
}

@Model
public class TemplateRule {
    @Attribute(.unique) public var id: UUID
    public var attribute: RuleAttribute
    public var pattern: String
    public var templateContent: String
    
    public init(attribute: RuleAttribute, pattern: String, templateContent: String) {
        self.id = UUID()
        self.attribute = attribute
        self.pattern = pattern
        self.templateContent = templateContent
    }
}
