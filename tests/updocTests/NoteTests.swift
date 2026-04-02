import Testing
import Foundation
@testable import updoc

struct NoteTests {
    @Test func noteInitializesWithCorrectTitle() {
        let title = "Test Meeting"
        let note = Note(title: title, content: "Test content")
        #expect(note.title == title)
    }
    
    @Test func noteInitializesWithCorrectContent() {
        let content = "Detailed meeting notes."
        let note = Note(title: "Title", content: content)
        #expect(note.content == content)
    }
    
    @Test func noteInitializesWithRecentCreatedAt() {
        let note = Note(title: "Title", content: "Content")
        let now = Date()
        // Check that the note was created within the last second
        #expect(abs(note.createdAt.timeIntervalSince(now)) < 1.0)
    }
    
    @Test func noteEqualityIsBasedOnId() {
        let note1 = Note(title: "Same", content: "Same")
        let note2 = Note(title: "Same", content: "Same")
        
        // Even if content is same, they are different notes with different IDs
        #expect(note1 != note2)
        #expect(note1 == note1)
    }
}
