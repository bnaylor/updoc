import Foundation

public struct SmartTemplateEngine {
    public init() {}
    
    public func resolveTemplate(for event: CalendarEvent, rules: [TemplateRule]) -> String {
        for rule in rules {
            if rule.attribute == "Title" && event.summary.contains(rule.pattern) {
                return apply(template: rule.templateContent, to: event)
            }
        }
        // Default template
        return "# \(event.summary)\n\nDate: \(event.start.formatted())\n\n## Notes\n- "
    }
    
    private func apply(template: String, to event: CalendarEvent) -> String {
        return template
            .replacingOccurrences(of: "{{title}}", with: event.summary)
            .replacingOccurrences(of: "{{date}}", with: event.start.formatted())
    }
}
