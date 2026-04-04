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
    
    @Test func detectsStandardImageSyntax() throws {
        let text = "Check this out: ![My Image](https://example.com/image.png)"
        let ranges = engine.parse(text)
        
        let imageRange = try #require(ranges.first { 
            if case .image(let url, let title) = $0.style {
                return url == "https://example.com/image.png" && title == "My Image"
            }
            return false
        })
        #expect(imageRange.range.length == 42) // length of "![My Image](https://example.com/image.png)"
    }
    
    @Test func detectsLocalAssetSyntax() throws {
        let text = "Check this out: ![[my-asset-123]]"
        let ranges = engine.parse(text)
        
        let assetRange = try #require(ranges.first { 
            if case .image(let url, let title) = $0.style {
                return url == "asset://my-asset-123" && title == nil
            }
            return false
        })
        #expect(assetRange.range.length == 17) // length of "![[my-asset-123]]"
    }
}
