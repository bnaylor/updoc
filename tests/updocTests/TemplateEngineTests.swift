// tests/updocTests/TemplateEngineTests.swift
import Testing
import Foundation
@testable import updoc

struct TemplateEngineTests {
    @Test func resolveTemplateAppliesMatchingRule() {
        let engine = SmartTemplateEngine()
        let rule = TemplateRule(attribute: "Title", pattern: "1:1", templateContent: "# 1:1 w/ {{title}}")
        let event = CalendarEvent(id: "1", summary: "Weekly 1:1", description: nil, location: nil, start: .now, attendees: [])
        
        let result = engine.resolveTemplate(for: event, rules: [rule])
        #expect(result == "# 1:1 w/ Weekly 1:1")
    }
    
    @Test func resolveTemplateReturnsDefaultIfNoMatch() {
        let engine = SmartTemplateEngine()
        let event = CalendarEvent(id: "1", summary: "Random Meeting", description: nil, location: nil, start: .now, attendees: [])
        
        let result = engine.resolveTemplate(for: event, rules: [])
        #expect(result.contains("# Random Meeting"))
    }
}
