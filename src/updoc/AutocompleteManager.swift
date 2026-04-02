// AutocompleteManager.swift
import Foundation

public enum AutocompleteMatch: Sendable {
    case person(Person)
    case date(Date)
}

public struct AutocompleteManager {
    public init() {}
    
    public func findMatches(for query: String) async throws -> [AutocompleteMatch] {
        var matches: [AutocompleteMatch] = []
        
        // Check dates
        if let date = DateService.parse(query) {
            matches.append(.date(date))
        }
        
        // Check people
        let people = try await MomaService.shared.searchPeople(query: query)
        matches.append(contentsOf: people.map { .person($0) })
        
        return matches
    }
}
