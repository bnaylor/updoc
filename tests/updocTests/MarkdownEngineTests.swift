import Testing
import Foundation
@testable import updoc

struct MarkdownEngineTests {
    let engine = MarkdownEngine()
    
    @Test func detectsLevelOneHeading() {
        let text = "# This is a heading"
        let ranges = engine.parse(text)
        
        #expect(ranges.count == 1)
        #expect(ranges.first?.style == .heading(level: 1))
        #expect(ranges.first?.range.length == text.count)
    }
    
    @Test func detectsBoldText() throws {
        let text = "This is **bold** text"
        let ranges = engine.parse(text)
        
        // Should find "**bold**"
        let boldRange = try #require(ranges.first { $0.style == .bold })
        #expect(boldRange.range.length == 8) // length of "**bold**"
    }
    
    @Test func detectsItalicText() throws {
        let text = "This is *italic* text"
        let ranges = engine.parse(text)
        
        // Should find "*italic*"
        let italicRange = try #require(ranges.first { $0.style == .italic })
        #expect(italicRange.range.length == 8) // length of "*italic*"
    }
    
    @Test func detectsMultipleStylesInOneString() {
        let text = "# Title\nWith **bold** and *italic*"
        let ranges = engine.parse(text)
        
        #expect(ranges.count == 3)
        #expect(ranges.contains { $0.style == .heading(level: 1) })
        #expect(ranges.contains { $0.style == .bold })
        #expect(ranges.contains { $0.style == .italic })
    }
}
