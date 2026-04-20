// tests/updocTests/TemplateEngineTests.swift
import Testing
import Foundation
@testable import updoc

struct TemplateEngineTests {
    @Test func resolveTemplateAppliesTitleRule() {
        let engine = SmartTemplateEngine()
        let rule = TemplateRule(attribute: .title, pattern: "1:1", templateContent: "# 1:1 w/ {{title}}")
        let input = TemplateInput(title: "Weekly 1:1", attendees: [])
        
        let result = engine.resolveTemplate(for: input, rules: [rule])
        #expect(result.content == "# 1:1 w/ Weekly 1:1")
    }
    
    @Test func resolveTemplateAppliesParticipantRule() {
        let engine = SmartTemplateEngine()
        let rule = TemplateRule(attribute: .participant, pattern: "Duckie", templateContent: "# Sync with Duckie")
        let input = TemplateInput(title: "Project Update", attendees: ["duckie@google.com"])
        
        let result = engine.resolveTemplate(for: input, rules: [rule])
        #expect(result.content == "# Sync with Duckie")
    }
    
    @Test func resolveTemplateAppliesParticipantCountExactRule() {
        let engine = SmartTemplateEngine()
        let rule = TemplateRule(attribute: .participantCount, pattern: "2", templateContent: "# 1:1 Meeting")
        let input = TemplateInput(title: "Chat", attendees: ["User A", "User B"])
        
        let result = engine.resolveTemplate(for: input, rules: [rule])
        #expect(result.content == "# 1:1 Meeting")
    }
    
    @Test func resolveTemplateAppliesParticipantCountGreaterRule() {
        let engine = SmartTemplateEngine()
        let rule = TemplateRule(attribute: .participantCount, pattern: ">2", templateContent: "# Group Meeting")
        let input = TemplateInput(title: "Standup", attendees: ["User A", "User B", "User C"])
        
        let result = engine.resolveTemplate(for: input, rules: [rule])
        #expect(result.content == "# Group Meeting")
    }
    
    @Test func resolveTemplateAppliesParticipantCountLessRule() {
        let engine = SmartTemplateEngine()
        let rule = TemplateRule(attribute: .participantCount, pattern: "<2", templateContent: "# Solo Work")
        let input = TemplateInput(title: "Focus", attendees: ["User A"])
        
        let result = engine.resolveTemplate(for: input, rules: [rule])
        #expect(result.content == "# Solo Work")
    }
    
    @Test func applyTemplateSupportsAllPlaceholders() {
        let engine = SmartTemplateEngine()
        let template = "{{title}} | {{location}} | {{attendees}}"
        let input = TemplateInput(title: "Title", attendees: ["User A", "User B"], location: "Room 1")
        
        let rule = TemplateRule(attribute: .title, pattern: "Title", templateContent: template)
        let result = engine.resolveTemplate(for: input, rules: [rule])
        #expect(result.content == "Title | Room 1 | User A, User B")
    }
    
    @Test func resolveTemplateReturnsDefaultIfNoMatch() {
        let engine = SmartTemplateEngine()
        let input = TemplateInput(title: "Random Meeting", attendees: [])
        
        let result = engine.resolveTemplate(for: input, rules: [])
        #expect(result.content.contains("# Random Meeting"))
    }
}
