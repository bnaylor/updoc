import Testing
import Foundation
import SwiftData
@testable import updoc

@MainActor
struct SyncTests {
    @Test func syncCoordinatorMergesContentOnConflict() async throws {
        let coordinator = SyncCoordinator()
        let local = "# Local"
        let remote = "# Remote"
        let merged = coordinator.merge(local: local, remote: remote)
        
        #expect(merged.contains("# Local"))
        #expect(merged.contains("# Remote"))
    }
    
    @Test func syncFailsWhenNotAuthenticated() async throws {
        let coordinator = SyncCoordinator()
        // Create a model context for the test
        let schema = Schema([Note.self, ActionItem.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext
        
        let note = Note(title: "Test", content: "Local", googleDocId: "test-id")
        context.insert(note)
        
        await #expect(throws: SyncError.notAuthenticated) {
            try await coordinator.sync(noteId: note.persistentModelID, in: context)
        }
    }
}
