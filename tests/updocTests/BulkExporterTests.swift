import Testing
import Foundation
import SwiftData
@testable import updoc

struct BulkExporterTests {
    @Test func exportNotesCreatesHierarchyAndFrontmatter() async throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Note.self, Folder.self, configurations: config)
        let context = ModelContext(container)
        
        let workFolder = Folder(name: "Work")
        let projectFolder = Folder(name: "Project X", parent: workFolder)
        let emptyFolder = Folder(name: "Empty Folder")
        context.insert(workFolder)
        context.insert(projectFolder)
        context.insert(emptyFolder)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date1 = formatter.date(from: "2026-07-08")!
        let date2 = formatter.date(from: "2026-07-09")!
        
        let note1 = Note(
            title: "Meeting Note",
            content: "# Discussion\n- Point A",
            createdAt: date1,
            googleDocId: "doc_123",
            meetingID: "mtg_456",
            folder: projectFolder,
            themeName: "modern"
        )
        
        // Note 2: standard note in folder
        let note2 = Note(
            title: "Meeting Note",
            content: "# Followup",
            createdAt: date2,
            folder: projectFolder
        )
        
        // Note 2 Dup: duplicate title in same folder (should become Meeting Note 2.md)
        let note2Dup = Note(
            title: "Meeting Note",
            content: "# Followup 2",
            createdAt: date2,
            folder: projectFolder
        )
        
        // Note 3: note with existing frontmatter
        let note3 = Note(
            title: "Existing FM",
            content: "---\ncustomKey: customVal\n---\n# Existing",
            createdAt: date2,
            folder: workFolder
        )
        
        // Note 4: root note without folder
        let note4 = Note(
            title: "Root Note",
            content: "Just a root note",
            createdAt: date2
        )
        
        context.insert(note1)
        context.insert(note2)
        context.insert(note2Dup)
        context.insert(note3)
        context.insert(note4)
        try context.save()
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let exporter = BulkExporter(modelContainer: container)
        let count = try await exporter.exportNotes(to: tempDir)
        
        #expect(count == 5)
        
        // Verify folder structure created
        let workDir = tempDir.appendingPathComponent("Work")
        let projectDir = workDir.appendingPathComponent("Project X")
        let emptyDir = tempDir.appendingPathComponent("Empty Folder")
        let meetingDir = tempDir.appendingPathComponent("2026/07/08")
        
        #expect(FileManager.default.fileExists(atPath: workDir.path))
        #expect(FileManager.default.fileExists(atPath: projectDir.path))
        #expect(FileManager.default.fileExists(atPath: emptyDir.path))
        #expect(FileManager.default.fileExists(atPath: meetingDir.path))
        
        // Verify Note 1 in 2026/07/08/Meeting Note.md
        let note1Path = meetingDir.appendingPathComponent("Meeting Note.md")
        #expect(FileManager.default.fileExists(atPath: note1Path.path))
        let note1Content = try String(contentsOf: note1Path, encoding: .utf8)
        #expect(note1Content.contains("meetingId: mtg_456"))
        #expect(note1Content.contains("date: 2026-07-08"))
        #expect(note1Content.contains("cssclasses: modern"))
        #expect(note1Content.contains("googleDocId: doc_123"))
        #expect(note1Content.contains("# Discussion"))
        
        // Verify Note 2 and Note 2 Dup in Work/Project X/
        let note2Path = projectDir.appendingPathComponent("Meeting Note.md")
        let note2DupPath = projectDir.appendingPathComponent("Meeting Note 2.md")
        #expect(FileManager.default.fileExists(atPath: note2Path.path))
        #expect(FileManager.default.fileExists(atPath: note2DupPath.path))
        
        // Verify Note 3 preserves existing frontmatter
        let note3Path = workDir.appendingPathComponent("Existing FM.md")
        #expect(FileManager.default.fileExists(atPath: note3Path.path))
        let note3Content = try String(contentsOf: note3Path, encoding: .utf8)
        #expect(note3Content.contains("customKey: customVal"))
        #expect(note3Content.contains("date: 2026-07-09"))
        
        // Verify Note 4 in root tempDir
        let note4Path = tempDir.appendingPathComponent("Root Note.md")
        #expect(FileManager.default.fileExists(atPath: note4Path.path))
    }
}
