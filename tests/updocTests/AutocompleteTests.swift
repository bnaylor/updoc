// tests/updocTests/AutocompleteTests.swift
import Testing
import Foundation
@testable import updoc

actor MockMomaService {
    var callCount = 0
    func searchPeople(query: String) async throws -> [Person] {
        callCount += 1
        return [Person(id: "1", name: "Test", email: "test@example.com")]
    }
}

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
        let manager = AutocompleteManager()
        do {
            let results = try await manager.findMatches(for: "today")
            #expect(results.count > 0)
        } catch {
            if Config.momaAPIURL.isEmpty || error is CancellationError {
                return
            }
            throw error
        }
    }
    
    @Test func autocompleteManagerCachesResults() async throws {
        let mockService = MockMomaService()
        let manager = AutocompleteManager(searchPeople: { try await mockService.searchPeople(query: $0) })
        
        let results1 = try await manager.findMatches(for: "test")
        let results2 = try await manager.findMatches(for: "test")
        
        #expect(results1.count > 0)
        #expect(results2.count > 0)
        
        let count = await mockService.callCount
        #expect(count == 1) // Verified it was cached
    }
    
    @Test func autocompleteManagerDebouncesRapidCalls() async throws {
        let mockService = MockMomaService()
        let manager = AutocompleteManager(searchPeople: { try await mockService.searchPeople(query: $0) })
        
        let task1 = Task {
            try await manager.findMatches(for: "t")
        }
        
        // Wait less than the 300ms debounce window
        try await Task.sleep(nanoseconds: 50_000_000)
        
        let task2 = Task {
            try await manager.findMatches(for: "te")
        }
        
        do {
            _ = try await task1.value
            Issue.record("Expected task1 to throw CancellationError")
        } catch is CancellationError {
            // Expected: the first request was superseded
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        
        let results2 = try await task2.value
        #expect(results2.count > 0)
        
        let count = await mockService.callCount
        #expect(count == 1) // Only the final debounced call executes
    }
}
