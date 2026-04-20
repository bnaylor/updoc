import Foundation
import SwiftData

public enum RuleAttribute: String, Codable, CaseIterable {
    case title = "Title"
    case participant = "Participant"
    case participantCount = "Participant Count"
}

@Model
public class TemplateRule {
    public var id: UUID
    public var attribute: RuleAttribute
    public var pattern: String
    public var templateContent: String
    public var themeName: String?
    
    public init(attribute: RuleAttribute, pattern: String, templateContent: String, themeName: String? = nil) {
        self.id = UUID()
        self.attribute = attribute
        self.pattern = pattern
        self.templateContent = templateContent
        self.themeName = themeName
    }
}
