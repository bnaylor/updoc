import XCTest
import SwiftData
@testable import updoc

@MainActor
final class EditorSyncTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, ActionItem.self, configurations: config)
        let context = container.mainContext
        
        await MainActor.run {
            self.container = container
            self.context = context
        }
    }
    
    func testSyncTaskStatusToNoteContent() {
        let content = """
        # Meeting Notes
        
        - [ ] Task 1
        - [ ] Task 2
        """
        let note = Note(title: "Sync Test", content: content)
        let task1 = ActionItem(title: "Task 1", status: .todo)
        task1.note = note
        
        context.insert(note)
        context.insert(task1)
        
        // When task1 is toggled to .done
        task1.status = .done
        note.updateContent(for: task1)
        
        let expectedContent = """
        # Meeting Notes
        
        - [x] Task 1
        - [ ] Task 2
        """
        XCTAssertEqual(note.content, expectedContent)
        
        // When task1 is toggled back to .todo
        task1.status = .todo
        note.updateContent(for: task1)
        
        XCTAssertEqual(note.content, content)
    }

    func testSyncTaskStatusToNoteContentWithDifferentMarkers() {
        let content = """
        * [ ] Star task
        1. [ ] Numbered task
        - [X] Already done
        """
        let note = Note(title: "Markers Test", content: content)
        let task1 = ActionItem(title: "Star task", status: .todo)
        let task2 = ActionItem(title: "Already done", status: .done)
        task1.note = note
        task2.note = note
        
        context.insert(note)
        context.insert(task1)
        context.insert(task2)
        
        // Toggle task1 to done
        task1.status = .done
        note.updateContent(for: task1)
        XCTAssertTrue(note.content.contains("* [x] Star task"))
        
        // Toggle task2 to todo
        task2.status = .todo
        note.updateContent(for: task2)
        XCTAssertTrue(note.content.contains("- [ ] Already done"))
    }
}
