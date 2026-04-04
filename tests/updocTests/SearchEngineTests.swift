import XCTest
@testable import updoc

final class SearchEngineTests: XCTestCase {
    var searchEngine: SearchEngine!
    
    override func setUp() {
        super.setUp()
        searchEngine = SearchEngine()
    }
    
    func testSearchReturnsResultsForMatchingContent() {
        // Given
        let note1 = Note(title: "Meeting Notes", content: "This is a test note about Swift development.")
        let note2 = Note(title: "Shopping List", content: "Buy apples, bananas, and milk.")
        let notes = [note1, note2]
        let query = "Swift"
        
        // When
        let results = searchEngine.search(query: query, in: notes)
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.note.title, "Meeting Notes")
        XCTAssertFalse(results.first?.snippets.isEmpty ?? true)
    }
    
    func testSearchIsCaseInsensitive() {
        // Given
        let note = Note(title: "Test", content: "SWIFT development is FUN.")
        let query = "swift"
        
        // When
        let results = searchEngine.search(query: query, in: [note])
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.snippets.count, 1)
        let snippet = results.first?.snippets.first
        let nsText = (snippet?.text ?? "") as NSString
        XCTAssertEqual(nsText.substring(with: snippet?.matchRange ?? NSRange()), "SWIFT")
    }
    
    func testSearchReturnsMultipleSnippetsForMultipleMatches() {
        // Given
        let note = Note(title: "Test", content: "Swift is great. I love Swift.")
        let query = "Swift"
        
        // When
        let results = searchEngine.search(query: query, in: [note])
        
        // Then
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.snippets.count, 2)
    }
    
    func testSnippetExtractionHandlesBoundaries() {
        // Given
        let content = "Start. " + String(repeating: "a", count: 50) + " MATCH " + String(repeating: "b", count: 50) + " .End"
        let note = Note(title: "Boundary Test", content: content)
        let query = "MATCH"
        
        // When
        let results = searchEngine.search(query: query, in: [note])
        
        // Then
        let snippet = results.first?.snippets.first
        XCTAssertNotNil(snippet)
        
        // Check snippet length (approx 40 before + 5 match + 40 after = 85)
        XCTAssertTrue((snippet?.text.count ?? 0) <= 85)
        
        // Verify match is correct in snippet
        let nsText = (snippet?.text ?? "") as NSString
        XCTAssertEqual(nsText.substring(with: snippet?.matchRange ?? NSRange()), "MATCH")
    }
    
    func testEmptyQueryReturnsNoResults() {
        // Given
        let note = Note(title: "Test", content: "Some content.")
        let query = ""
        
        // When
        let results = searchEngine.search(query: query, in: [note])
        
        // Then
        XCTAssertTrue(results.isEmpty)
    }
    
    func testSnippetExtractionProvidesAbsoluteRange() {
        // Given
        let content = "First part of the text. MATCH here. Last part."
        let note = Note(title: "Absolute Range Test", content: content)
        let query = "MATCH"
        
        // When
        let results = searchEngine.search(query: query, in: [note])
        
        // Then
        let snippet = results.first?.snippets.first
        XCTAssertNotNil(snippet)
        
        // Match in 'content' is at index 24, length 5
        XCTAssertEqual(snippet?.absoluteRange.location, 24)
        XCTAssertEqual(snippet?.absoluteRange.length, 5)
        
        // Verify snippet correctly contains match
        let nsContent = content as NSString
        XCTAssertEqual(nsContent.substring(with: snippet?.absoluteRange ?? NSRange()), "MATCH")
    }
}
