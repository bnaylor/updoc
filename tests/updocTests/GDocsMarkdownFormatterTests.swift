import Testing
import Foundation
@testable import updoc

struct GDocsMarkdownFormatterTests {
    let formatter = GDocsMarkdownFormatter()
    
    @Test func formatsLevelOneHeading() {
        let text = "# Meeting"
        let result = formatter.format(text)
        
        #expect(result.cleanText == "Meeting")
        #expect(result.requests.count == 1)
        guard let req = result.requests.first?.updateParagraphStyle else {
            Issue.record("Expected updateParagraphStyle request")
            return
        }
        #expect(req.paragraphStyle.namedStyleType == "HEADING_1")
        #expect(req.range.startIndex == 1)
        #expect(req.range.endIndex == 8)
    }
    
    @Test func formatsBoldText() {
        let text = "Hello **World**"
        let result = formatter.format(text)
        
        #expect(result.cleanText == "Hello World")
        #expect(result.requests.count == 1)
        guard let req = result.requests.first?.updateTextStyle else {
            Issue.record("Expected updateTextStyle request")
            return
        }
        #expect(req.textStyle.bold == true)
        #expect(req.range.startIndex == 7) // "Hello " is 6 chars, body starts at index 1
        #expect(req.range.endIndex == 12)  // "World" is 5 chars
    }
    
    @Test func formatsItalicText() {
        let text = "Hello *World*"
        let result = formatter.format(text)
        
        #expect(result.cleanText == "Hello World")
        #expect(result.requests.count == 1)
        guard let req = result.requests.first?.updateTextStyle else {
            Issue.record("Expected updateTextStyle request")
            return
        }
        #expect(req.textStyle.italic == true)
        #expect(req.range.startIndex == 7)
        #expect(req.range.endIndex == 12)
    }
    
    @Test func formatsCodeText() {
        let text = "Code `block`"
        let result = formatter.format(text)
        
        #expect(result.cleanText == "Code block")
        #expect(result.requests.count == 1)
        guard let req = result.requests.first?.updateTextStyle else {
            Issue.record("Expected updateTextStyle request")
            return
        }
        #expect(req.textStyle.weightedFontFamily?.fontFamily == "Courier New")
        #expect(req.range.startIndex == 6)
        #expect(req.range.endIndex == 11)
    }
    
    @Test func formatsLinks() {
        let text = "Check [Google](https://google.com)"
        let result = formatter.format(text)
        
        #expect(result.cleanText == "Check Google")
        #expect(result.requests.count == 1)
        guard let req = result.requests.first?.updateTextStyle else {
            Issue.record("Expected updateTextStyle request")
            return
        }
        #expect(req.textStyle.link?.url == "https://google.com")
        #expect(req.range.startIndex == 7)
        #expect(req.range.endIndex == 13)
    }
    
    @Test func formatsBoldInHeading() {
        let text = "# This is **bold**"
        let result = formatter.format(text)
        
        #expect(result.cleanText == "This is bold")
        
        // Heading request
        let headingReq = result.requests.compactMap { $0.updateParagraphStyle }.first
        #expect(headingReq?.paragraphStyle.namedStyleType == "HEADING_1")
        #expect(headingReq?.range.startIndex == 1)
        #expect(headingReq?.range.endIndex == 13)
        
        // Bold request
        let boldReq = result.requests.compactMap { $0.updateTextStyle }.first
        #expect(boldReq?.textStyle.bold == true)
        #expect(boldReq?.range.startIndex == 9) // "# " stripped, "This is " is 8 chars. Offset 1 -> 9
        #expect(boldReq?.range.endIndex == 13)
    }
    
    @Test func formatsMultipleStylesOnOneLine() {
        let text = "*Italic* and **Bold**"
        let result = formatter.format(text)
        
        #expect(result.cleanText == "Italic and Bold")
        
        let styles = result.requests.compactMap { $0.updateTextStyle }
        #expect(styles.count == 2)
        
        let italic = styles[0]
        #expect(italic.textStyle.italic == true)
        #expect(italic.range.startIndex == 1)
        #expect(italic.range.endIndex == 7)
        
        let bold = styles[1]
        #expect(bold.textStyle.bold == true)
        #expect(bold.range.startIndex == 12) // "Italic and " is 11 chars. Offset 1 -> 12
        #expect(bold.range.endIndex == 16)
    }
}
