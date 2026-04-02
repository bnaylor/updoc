// MomaService.swift
import Foundation

public struct Person: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let email: String
    
    public init(id: String, name: String, email: String) {
        self.id = id
        self.name = name
        self.email = email
    }
}

public actor MomaService {
    public static let shared = MomaService()
    public init() {}
    
    public func searchPeople(query: String) async throws -> [Person] {
        // Mock search: if query matches "duck", return Duckie
        if query.lowercased().contains("duck") {
            return [Person(id: "1", name: "Duckie", email: "duckie@google.com")]
        }
        return []
    }
}
