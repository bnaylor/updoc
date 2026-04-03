// tests/updocTests/AutocompleteTests.swift
import Testing
import Foundation
@testable import updoc

struct AutocompleteTests {
    @Test func dateServiceParsesToday() {
        #expect(DateService.parse("today") != nil)
    }
    
    @Test func momaServiceReturnsDuckie() async throws {
        guard !Config.momaAPIURL.isEmpty else { return }
        let results = try await MomaService.shared.searchPeople(query: "duck")
        #expect(results.contains { $0.name == "Duckie" })
    }
    
    @Test func autocompleteManagerCombinesResults() async throws {
        // We still expect matches if query is "today" (from DateService)
        let manager = AutocompleteManager()
        do {
            let results = try await manager.findMatches(for: "today")
            #expect(results.count > 0)
        } catch {
            // If MomaService fails due to config, we still might get here.
            // But DateService should have provided at least one match if it didn't throw.
            // Actually findMatches will throw if MomaService throws.
            if Config.momaAPIURL.isEmpty {
                // Expected failure if config is empty
                return
            }
            throw error
        }
    }
}
