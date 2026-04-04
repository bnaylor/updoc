import XCTest
@testable import updoc

final class TagManagerTests: XCTestCase {
    var tagManager: TagManager!
    
    override func setUp() {
        super.setUp()
        tagManager = TagManager()
    }
    
    func testExtractTags_SimpleTags() {
        let content = "This is a #tag and another #one."
        let tags = tagManager.extractTags(from: content)
        XCTAssertEqual(tags, ["tag", "one"])
    }
    
    func testExtractTags_HyphenatedAndNestedTags() {
        let content = "Project #work-item and nested #group/subgroup."
        let tags = tagManager.extractTags(from: content)
        XCTAssertEqual(tags, ["work-item", "group/subgroup"])
    }
    
    func testExtractTags_Boundaries() {
        let content = "#start of line, end of line #end! #middle? #tag."
        let tags = tagManager.extractTags(from: content)
        XCTAssertTrue(tags.contains("start"))
        XCTAssertTrue(tags.contains("end"))
        XCTAssertTrue(tags.contains("middle"))
        XCTAssertTrue(tags.contains("tag"))
        XCTAssertEqual(tags.count, 4)
    }
    
    func testGetAllTags_AggregatesAndSorts() {
        let notes = [
            Note(title: "Note 1", content: "Working on #project1 and #task1."),
            Note(title: "Note 2", content: "Updates for #project1 and #new-idea."),
            Note(title: "Note 3", content: "No tags here.")
        ]
        let allTags = tagManager.getAllTags(in: notes)
        XCTAssertEqual(allTags, ["new-idea", "project1", "task1"])
    }
    
    func testExtractTags_EmptyContent() {
        let tags = tagManager.extractTags(from: "")
        XCTAssertTrue(tags.isEmpty)
    }
    
    func testExtractTags_NoTags() {
        let tags = tagManager.extractTags(from: "Just some text without any hashtags.")
        XCTAssertTrue(tags.isEmpty)
    }
}
