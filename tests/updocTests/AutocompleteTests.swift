// tests/updocTests/AutocompleteTests.swift
import Testing
import Foundation
@testable import updoc

struct AutocompleteTests {
    @Test func dateServiceParsesToday() {
        #expect(DateService.parse("today") != nil)
    }
    
    @Test func momaServiceReturnsDuckie() async throws {
        let results = try await MomaService.shared.searchPeople(query: "duck")
        #expect(results.contains { $0.name == "Duckie" })
    }
    
    @Test func autocompleteManagerCombinesResults() async throws {
        let manager = AutocompleteManager()
        let results = try await manager.findMatches(for: "today")
        #expect(results.count > 0)
    }
}
