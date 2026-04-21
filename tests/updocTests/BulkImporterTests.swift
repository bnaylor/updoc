import Testing
import Foundation
import SwiftData
@testable import updoc

struct BulkImporterTests {
    @Test func importNotesCreatesFoldersAndNotes() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, Folder.self, configurations: config)
        
        let json = """
        [
          {
            "title": "Test Note 1",
            "url": "https://docs.google.com/document/d/1234567890",
            "createdAt": "2026-04-21T12:00:00Z",
            "folderPath": "Work/Project X"
          }
        ]
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("import_test.json")
        try Data(json.utf8).write(to: fileURL)
        
        let importer = BulkImporter(modelContainer: container)
        try await importer.importNotes(from: fileURL)
        
        let context = ModelContext(container)
        
        // Verify folders
        let folderDescriptor = FetchDescriptor<Folder>()
        let folders = try context.fetch(folderDescriptor)
        
        #expect(folders.count == 2)
        let workFolder = folders.first { $0.name == "Work" }
        let projectFolder = folders.first { $0.name == "Project X" }
        
        #expect(workFolder != nil)
        #expect(projectFolder != nil)
        #expect(projectFolder?.parent == workFolder)
        
        // Verify notes
        let noteDescriptor = FetchDescriptor<Note>()
        let notes = try context.fetch(noteDescriptor)
        
        #expect(notes.count == 1)
        let note = notes.first
        #expect(note?.title == "Test Note 1")
        #expect(note?.googleDocId == "1234567890")
        #expect(note?.folder == projectFolder)
        #expect(note?.isReadOnly == true)
        
        // Clean up
        try FileManager.default.removeItem(at: fileURL)
    }
}
