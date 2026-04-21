// AutocompleteManager.swift
import Foundation

public enum AutocompleteMatch: Sendable, Hashable {
    case person(Person)
    case date(Date)
}

public actor AutocompleteManager {
    private var cache: [String: [Person]] = [:]
    private var currentTaskID: UUID = UUID()
    
    // Injected closure for easier testing
    private let searchPeople: @Sendable (String) async throws -> [Person]
    
    public init(searchPeople: @escaping @Sendable (String) async throws -> [Person] = { _ in [] }) {
        self.searchPeople = searchPeople
    }
    
    public func findMatches(for query: String) async throws -> [AutocompleteMatch] {
        let taskID = UUID()
        self.currentTaskID = taskID
        
        // Debounce: sleep for 300ms
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Check if a newer query has superseded this task
        guard self.currentTaskID == taskID else {
            throw CancellationError()
        }
        
        var matches: [AutocompleteMatch] = []
        
        // Check dates
        if let date = DateService.parse(query) {
            matches.append(.date(date))
        }
        
        // Check people: use cache or fetch from service
        let people: [Person]
        if let cached = cache[query] {
            people = cached
        } else {
            people = try await searchPeople(query)
            
            // Re-verify task cancellation in case another query started while awaiting the network request
            guard self.currentTaskID == taskID else {
                throw CancellationError()
            }
            
            cache[query] = people
        }
        
        matches.append(contentsOf: people.map { .person($0) })
        return matches
    }
}
