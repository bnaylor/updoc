import Foundation
import UniformTypeIdentifiers

public struct GDriveResponse: Codable {
    public let headRevisionId: String?
}

public struct GDriveFile: Codable {
    public let id: String
    public let name: String
    public let mimeType: String
}

public struct GDriveSearchResponse: Codable {
    public let files: [GDriveFile]
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

    public func getOrCreateFolder(named name: String, parentId: String? = nil) async throws -> String {
        let token = try await AuthManager.shared.getAccessToken()
        var query = "name = '\(name)' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        if let parentId = parentId {
            query += " and '\(parentId)' in parents"
        }
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw NSError(domain: "GDriveService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode query"])
        }
        
        let searchUrl = URL(string: "https://www.googleapis.com/drive/v3/files?q=\(encodedQuery)")!
        var searchRequest = URLRequest(url: searchUrl)
        searchRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (searchData, searchResponse) = try await URLSession.shared.data(for: searchRequest)
        
        if let httpResponse = searchResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "GDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to search for folder"])
        }
        
        let driveSearchResponse = try JSONDecoder().decode(GDriveSearchResponse.self, from: searchData)
        
        if let existingFolder = driveSearchResponse.files.first {
            return existingFolder.id
        }
        
        // Create folder if not found
        let createUrl = URL(string: "https://www.googleapis.com/drive/v3/files")!
        var createRequest = URLRequest(url: createUrl)
        createRequest.httpMethod = "POST"
        createRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        createRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var metadata: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.folder"
        ]
        if let parentId = parentId {
            metadata["parents"] = [parentId]
        }
        createRequest.httpBody = try JSONSerialization.data(withJSONObject: metadata)
        
        let (createData, createResponse) = try await URLSession.shared.data(for: createRequest)
        
        if let httpResponse = createResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "GDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create folder"])
        }
        
        let createdFile = try JSONDecoder().decode(GDriveFile.self, from: createData)
        return createdFile.id
    }

    public func createDoc(name: String, parentId: String) async throws -> String {
        let token = try await AuthManager.shared.getAccessToken()
        let url = URL(string: "https://www.googleapis.com/drive/v3/files")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "mimeType": "application/vnd.google-apps.document",
            "parents": [parentId]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create doc: \(errorBody)"])
        }
        
        let file = try JSONDecoder().decode(GDriveFile.self, from: data)
        return file.id
    }

    public func uploadFile(data: Data, filename: String, parentId: String) async throws -> String {
        let token = try await AuthManager.shared.getAccessToken()
        let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")!
        
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Metadata part
        let metadata: [String: Any] = [
            "name": filename,
            "parents": [parentId]
        ]
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Media part
        let type = UTType(filenameExtension: (filename as NSString).pathExtension) ?? .data
        let mimeType = type.preferredMIMEType ?? "application/octet-stream"
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let responseString = String(data: responseData, encoding: .utf8) ?? "No error details"
            throw NSError(domain: "GDriveService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to upload file: \(responseString)"])
        }
        
        let uploadedFile = try JSONDecoder().decode(GDriveFile.self, from: responseData)
        return uploadedFile.id
    }
}
