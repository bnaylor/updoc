import Foundation

public struct ResolvedTemplate {
    public let content: String
    public let themeName: String?
}

public struct TemplateInput {
    public let title: String
    public let attendees: [String]
    public let date: Date
    public let location: String?
    public let description: String?
    
    public init(title: String, attendees: [String], date: Date = Date(), location: String? = nil, description: String? = nil) {
        self.title = title
        self.attendees = attendees
        self.date = date
        self.location = location
        self.description = description
    }
}

public struct SmartTemplateEngine {
    public init() {}
    
    public func resolveTemplate(for input: TemplateInput, rules: [TemplateRule]) -> ResolvedTemplate {
        for rule in rules {
            switch rule.attribute {
            case .title:
                if input.title.localizedCaseInsensitiveContains(rule.pattern) {
                    return ResolvedTemplate(content: apply(template: rule.templateContent, to: input), themeName: rule.themeName)
                }
            case .participant:
                if input.attendees.contains(where: { $0.localizedCaseInsensitiveContains(rule.pattern) }) {
                    return ResolvedTemplate(content: apply(template: rule.templateContent, to: input), themeName: rule.themeName)
                }
            }
        }
        return ResolvedTemplate(content: defaultTemplate(for: input), themeName: nil)
    }
    
    private func apply(template: String, to input: TemplateInput) -> String {
        return template
            .replacingOccurrences(of: "{{title}}", with: input.title)
            .replacingOccurrences(of: "{{date}}", with: input.date.formatted())
            .replacingOccurrences(of: "{{location}}", with: input.location ?? "")
            .replacingOccurrences(of: "{{description}}", with: input.description ?? "")
            .replacingOccurrences(of: "{{attendees}}", with: input.attendees.joined(separator: ", "))
    }
    
    private func defaultTemplate(for input: TemplateInput) -> String {
        return "# \(input.title)\n\nDate: \(input.date.formatted())\n\n## Notes\n- "
    }
}
