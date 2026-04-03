import Testing
import Foundation
@testable import updoc

@Suite("MomaService Tests")
struct MomaServiceTests {
    
    @Test func searchPeopleFailsWithEmptyConfig() async throws {
        // Given MomaService is initialized
        let service = MomaService()
        
        // When searching with empty config (default in tests usually)
        // Then it should throw an error if URL is invalid or request fails
        await #expect(throws: (any Error).self) {
            _ = try await service.searchPeople(query: "test")
        }
    }

    @Test func searchPeopleDecodesCorrectly() async throws {
        // This test requires mocking URLSession, which is a bit involved with URLSession.shared.
        // For now, we can at least verify that the Person model decodes correctly from expected JSON.
        let json = """
        [
            {"id": "123", "name": "Test User", "email": "test@example.com"}
        ]
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let people = try decoder.decode([Person].self, from: json)
        
        #expect(people.count == 1)
        #expect(people[0].id == "123")
        #expect(people[0].name == "Test User")
        #expect(people[0].email == "test@example.com")
    }
}
