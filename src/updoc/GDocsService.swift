import Foundation

public struct GDocsService: Sendable {
    public init() {}
    
    public func fetchDocContent(docId: String) async throws -> String {
        let token = try await AuthManager.shared.getAccessToken()
        let url = URL(string: "https://docs.googleapis.com/v1/documents/\(docId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch doc: \(errorBody)"])
        }
        
        let doc = try JSONDecoder().decode(GDocsDocument.self, from: data)
        return convertToMarkdown(doc)
    }
    
    public func updateDocContent(docId: String, content: String) async throws {
        // For simplicity in this implementation, we'll replace the entire body.
        // Google Docs batchUpdate requires complex range-based edits.
        // A common pattern for "replacing all" is:
        // 1. Delete existing content (from 1 to end-1)
        // 2. Insert new content at index 1
        
        let token = try await AuthManager.shared.getAccessToken()
        
        // We first need the end index to delete everything
        let url = URL(string: "https://docs.googleapis.com/v1/documents/\(docId)")!
        var getRequest = URLRequest(url: url)
        getRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: getRequest)
        let doc = try JSONDecoder().decode(GDocsDocument.self, from: data)
        
        // Find the end index of the body (excluding the final newline)
        let endIndex = doc.body.content.last?.endIndex ?? 2
        
        let deleteRequest = GDocsRequest(insertText: nil, deleteContentRange: GDocsDeleteContentRangeRequest(range: GDocsRange(startIndex: 1, endIndex: max(1, endIndex - 1))), insertInlineImage: nil, updateEmbeddedObjectProperties: nil)
        let insertRequest = GDocsRequest(insertText: GDocsInsertTextRequest(text: content, location: GDocsLocation(index: 1)), deleteContentRange: nil, insertInlineImage: nil, updateEmbeddedObjectProperties: nil)
        
        let batchRequest = GDocsBatchUpdateRequest(requests: [deleteRequest, insertRequest])
        let batchData = try JSONEncoder().encode(batchRequest)
        
        var updateRequest = URLRequest(url: URL(string: "https://docs.googleapis.com/v1/documents/\(docId):batchUpdate")!)
        updateRequest.httpMethod = "POST"
        updateRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateRequest.httpBody = batchData
        
        let (_, updateResponse) = try await URLSession.shared.data(for: updateRequest)
        
        if let httpResponse = updateResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update doc"])
        }
    }
    
    public func insertImage(docId: String, index: Int, uri: String, assetId: String) async throws {
        let token = try await AuthManager.shared.getAccessToken()
        
        let insertRequest = GDocsRequest(
            insertText: nil,
            deleteContentRange: nil,
            insertInlineImage: GDocsInsertInlineImageRequest(
                uri: uri,
                location: GDocsLocation(index: index)
            ),
            updateEmbeddedObjectProperties: nil
        )
        
        let batchRequest = GDocsBatchUpdateRequest(requests: [insertRequest])
        let batchData = try JSONEncoder().encode(batchRequest)
        
        var request = URLRequest(url: URL(string: "https://docs.googleapis.com/v1/documents/\(docId):batchUpdate")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = batchData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to insert image: \(errorBody)"])
        }
        
        let batchResponse = try JSONDecoder().decode(GDocsBatchUpdateResponse.self, from: data)
        guard let objectId = batchResponse.replies.first?.insertInlineImage?.objectId else {
            throw NSError(domain: "GDocsService", code: 0, userInfo: [NSLocalizedDescriptionKey: "No objectId returned after image insertion"])
        }
        
        try await tagImage(docId: docId, objectId: objectId, assetId: assetId)
    }
    
    private func tagImage(docId: String, objectId: String, assetId: String) async throws {
        let token = try await AuthManager.shared.getAccessToken()
        
        let tagRequest = GDocsRequest(
            insertText: nil,
            deleteContentRange: nil,
            insertInlineImage: nil,
            updateEmbeddedObjectProperties: GDocsUpdateEmbeddedObjectPropertiesRequest(
                objectId: objectId,
                properties: GDocsEmbeddedObjectProperties(description: "updoc_asset:\(assetId)"),
                fields: "description"
            )
        )
        
        let batchRequest = GDocsBatchUpdateRequest(requests: [tagRequest])
        let batchData = try JSONEncoder().encode(batchRequest)
        
        var request = URLRequest(url: URL(string: "https://docs.googleapis.com/v1/documents/\(docId):batchUpdate")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = batchData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to tag image: \(errorBody)"])
        }
    }
    
    private func convertToMarkdown(_ doc: GDocsDocument) -> String {
        var markdown = ""
        for element in doc.body.content {
            if let paragraph = element.paragraph {
                for element in paragraph.elements {
                    if let textRun = element.textRun, let content = textRun.content {
                        markdown += content
                    }
                }
            }
        }
        return markdown
    }
}
