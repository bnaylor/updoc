import Testing
import Foundation
@testable import updoc

struct CommandEngineTests {
    @Test func searchMatchesCommandsByTitle() {
        let engine = CommandEngine()
        let cmd = Command(title: "Sync Now", action: {})
        let results = engine.search(query: "sync", commands: [cmd], notes: [])
        #expect(results.count == 1)
        #expect(results.first?.title == "Sync Now")
    }
    
    @Test func searchMatchesNotesByTitle() {
        let engine = CommandEngine()
        let note = Note(title: "Project Plan", content: "...")
        let results = engine.search(query: "project", commands: [], notes: [note], onNoteSelect: { _ in })
        #expect(results.count == 1)
        #expect(results.first?.title == "Open Note: Project Plan")
    }
    
    @Test func searchIsCaseInsensitive() {
        let engine = CommandEngine()
        let cmd = Command(title: "Sync Now", action: {})
        let results = engine.search(query: "SYNC", commands: [cmd], notes: [])
        #expect(results.count == 1)
    }
    
    @Test func searchReturnsEmptyForNoMatch() {
        let engine = CommandEngine()
        let cmd = Command(title: "Sync Now", action: {})
        let results = engine.search(query: "archive", commands: [cmd], notes: [])
        #expect(results.isEmpty)
    }
    
    @Test func searchReturnsEmptyForEmptyQuery() {
        let engine = CommandEngine()
        let cmd = Command(title: "Sync Now", action: {})
        let results = engine.search(query: "", commands: [cmd], notes: [])
        #expect(results.isEmpty)
    }
}
