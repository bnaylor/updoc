import Foundation

public struct GDriveResponse: Codable {
    public let headRevisionId: String?
}

public struct GDriveService: Sendable {
    public init() {}
    
    public func getFileRevision(fileId: String) async throws -> String {
        let token = try await AuthManager.shared.getAccessToken()
        let url = URL(string: "https://www.googleapis.com/drive/v3/files/\(fileId)?fields=headRevisionId")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "GDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch file revision"])
        }
        
        let driveResponse = try JSONDecoder().decode(GDriveResponse.self, from: data)
        return driveResponse.headRevisionId ?? "unknown"
    }
}
