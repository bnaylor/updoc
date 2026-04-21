// MomaService.swift
import Foundation

public struct Person: Identifiable, Codable, Sendable, Hashable {
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
    
    public enum MomaError: Error {
        case invalidURL
        case requestFailed(Error)
        case invalidResponse
        case decodingError(Error)
    }
    
    public func searchPeople(query: String) async throws -> [Person] {
        guard let url = URL(string: "\(Config.momaAPIURL)/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)") else {
            throw MomaError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(Config.momaAPIKey, forHTTPHeaderField: "X-API-Key")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw MomaError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            do {
                return try decoder.decode([Person].self, from: data)
            } catch {
                throw MomaError.decodingError(error)
            }
        } catch let error as MomaError {
            throw error
        } catch {
            throw MomaError.requestFailed(error)
        }
    }
}
