import Foundation

public struct SmartTemplateEngine {
    public init() {}
    
    public func resolveTemplate(for event: CalendarEvent, rules: [TemplateRule]) -> String {
        for rule in rules {
            switch rule.attribute {
            case .title:
                if event.summary.localizedCaseInsensitiveContains(rule.pattern) {
                    return apply(template: rule.templateContent, to: event)
                }
            case .participant:
                if event.attendees.contains(where: { $0.localizedCaseInsensitiveContains(rule.pattern) }) {
                    return apply(template: rule.templateContent, to: event)
                }
            }
        }
        return defaultTemplate(for: event)
    }
    
    private func apply(template: String, to event: CalendarEvent) -> String {
        return template
            .replacingOccurrences(of: "{{title}}", with: event.summary)
            .replacingOccurrences(of: "{{date}}", with: event.start.formatted())
            .replacingOccurrences(of: "{{location}}", with: event.location ?? "")
            .replacingOccurrences(of: "{{description}}", with: event.description ?? "")
            .replacingOccurrences(of: "{{attendees}}", with: event.attendees.joined(separator: ", "))
    }
    
    private func defaultTemplate(for event: CalendarEvent) -> String {
        return "# \(event.summary)\n\nDate: \(event.start.formatted())\n\n## Notes\n- "
    }
}
