import Testing
import Foundation
@testable import updoc

struct ChecklistTests {
    @Test func markdownEngineDetectsSquareBracketChecklist() {
        let engine = MarkdownEngine()
        let text = "[ ] Task"
        let ranges = engine.parse(text)
        let checklistRange = ranges.first {
            if case .checklist(let done, _) = $0.style {
                return !done
            }
            return false
        }
        #expect(checklistRange != nil)
    }
    
    @Test func markdownEngineDetectsCheckmarkShortcut() {
        let engine = MarkdownEngine()
        let text = "√ Completed Task"
        let ranges = engine.parse(text)
        let checklistRange = ranges.first {
            if case .checklist(let done, _) = $0.style {
                return done
            }
            return false
        }
        #expect(checklistRange != nil)
    }

    @Test func checkmarkConversionLogic() {
        let text = "√ "
        let range = NSRange(location: 0, length: 2)
        let line = (text as NSString).substring(with: range)
        
        // This simulates what we'll do in EditorView
        if line.hasPrefix("√") {
            let newText = text.replacingOccurrences(of: "√", with: "[ ]")
            #expect(newText == "[ ] ")
        }
    }
}
