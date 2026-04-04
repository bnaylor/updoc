import XCTest
import SwiftData
@testable import updoc

@MainActor
final class ActionItemTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: Note.self, ActionItem.self, configurations: config)
        context = container.mainContext
    }
    
    func testActionItemStatusToggle() {
        let task = ActionItem(title: "Test Task", status: .todo)
        XCTAssertEqual(task.status, .todo)
        
        // Simulate sidebar toggle (set to done)
        task.status = .done
        XCTAssertEqual(task.status, .done)
        
        // Simulate sidebar toggle (set back to todo)
        task.status = .todo
        XCTAssertEqual(task.status, .todo)
    }
    
    func testActionItemNoteRelationship() {
        let note = Note(title: "Test Note", content: "Content")
        let task = ActionItem(title: "Test Task")
        
        task.note = note
        context.insert(note)
        context.insert(task)
        
        XCTAssertEqual(task.note?.title, "Test Note")
        XCTAssertTrue(note.actionItems.contains(where: { $0.title == "Test Task" }))
    }
}
