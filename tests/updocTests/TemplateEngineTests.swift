// tests/updocTests/TemplateEngineTests.swift
import Testing
import Foundation
@testable import updoc

struct TemplateEngineTests {
    @Test func resolveTemplateAppliesTitleRule() {
        let engine = SmartTemplateEngine()
        let rule = TemplateRule(attribute: .title, pattern: "1:1", templateContent: "# 1:1 w/ {{title}}")
        let event = CalendarEvent(id: "1", summary: "Weekly 1:1", description: nil, location: nil, start: .now, attendees: [])
        
        let result = engine.resolveTemplate(for: event, rules: [rule])
        #expect(result == "# 1:1 w/ Weekly 1:1")
    }
    
    @Test func resolveTemplateAppliesParticipantRule() {
        let engine = SmartTemplateEngine()
        let rule = TemplateRule(attribute: .participant, pattern: "Duckie", templateContent: "# Sync with Duckie")
        let event = CalendarEvent(id: "1", summary: "Project Update", description: nil, location: nil, start: .now, attendees: ["duckie@google.com"])
        
        let result = engine.resolveTemplate(for: event, rules: [rule])
        #expect(result == "# Sync with Duckie")
    }
    
    @Test func applyTemplateSupportsAllPlaceholders() {
        let engine = SmartTemplateEngine()
        let template = "{{title}} | {{location}} | {{attendees}}"
        let event = CalendarEvent(id: "1", summary: "Title", description: nil, location: "Room 1", start: .now, attendees: ["User A", "User B"])
        
        // Use a rule to trigger apply logic
        let rule = TemplateRule(attribute: .title, pattern: "Title", templateContent: template)
        let result = engine.resolveTemplate(for: event, rules: [rule])
        #expect(result == "Title | Room 1 | User A, User B")
    }
    
    @Test func resolveTemplateReturnsDefaultIfNoMatch() {
        let engine = SmartTemplateEngine()
        let event = CalendarEvent(id: "1", summary: "Random Meeting", description: nil, location: nil, start: .now, attendees: [])
        
        let result = engine.resolveTemplate(for: event, rules: [])
        #expect(result.contains("# Random Meeting"))
    }
}
