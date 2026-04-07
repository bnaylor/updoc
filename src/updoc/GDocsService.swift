import Foundation

public struct GDocsService: Sendable {
    public init() {}
    
    public func fetchDocContent(docId: String) async throws -> (markdown: String, document: GDocsDocument) {
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
        return (markdown: convertToMarkdown(doc), document: doc)
    }
    
    public func updateDocContent(docId: String, content: String, baseDocument: GDocsDocument, assetMappings: [String: String] = [:]) async throws {
        let token = try await AuthManager.shared.getAccessToken()
        
        let (requests, segments) = generateUpdateRequests(from: "", to: content, doc: baseDocument, assetMappings: assetMappings)
        
        if requests.isEmpty { return }
        
        let writeControl = GDocsWriteControl(requiredRevisionId: baseDocument.revisionId)
        
        // 1. Delete first
        let deleteBatchRequest = GDocsBatchUpdateRequest(requests: [requests[0]], writeControl: writeControl)
        let deleteBatchData = try JSONEncoder().encode(deleteBatchRequest)
        
        var updateRequest = URLRequest(url: URL(string: "https://docs.googleapis.com/v1/documents/\(docId):batchUpdate")!)
        updateRequest.httpMethod = "POST"
        updateRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        updateRequest.httpBody = deleteBatchData
        
        let (deleteData, deleteResponse) = try await URLSession.shared.data(for: updateRequest)
        if let httpResponse = deleteResponse as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: deleteData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete doc content: \(errorBody)"])
        }
        
        // 2. Insert everything
        let insertBatchRequest = GDocsBatchUpdateRequest(requests: Array(requests.dropFirst()), writeControl: writeControl)
        let insertBatchData = try JSONEncoder().encode(insertBatchRequest)
        updateRequest.httpBody = insertBatchData
        
        let (responseData, response) = try await URLSession.shared.data(for: updateRequest)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update doc: \(errorBody)"])
        }
        
        // Tag images if we have them
        let batchResponse = try JSONDecoder().decode(GDocsBatchUpdateResponse.self, from: responseData)
        var replyIdx = 0
        for segment in segments.reversed() {
            if case .image(_, let assetId) = segment {
                if let objectId = batchResponse.replies[replyIdx].insertInlineImage?.objectId {
                    try await tagImage(docId: docId, objectId: objectId, assetId: assetId)
                }
                replyIdx += 1
            } else {
                replyIdx += 1
            }
        }
    }
    
    private func generateUpdateRequests(from oldContent: String, to newContent: String, doc: GDocsDocument, assetMappings: [String: String]) -> ([GDocsRequest], [ContentSegment]) {
        let endIndex = doc.body.content.last?.endIndex ?? 2
        let segments = parseSegments(content: newContent, assetMappings: assetMappings)
        
        var requests: [GDocsRequest] = []
        
        // Delete existing content (from index 1 to endIndex-1)
        requests.append(GDocsRequest(
            insertText: nil,
            deleteContentRange: GDocsDeleteContentRangeRequest(range: GDocsRange(startIndex: 1, endIndex: max(1, endIndex - 1))),
            insertInlineImage: nil,
            updateEmbeddedObjectProperties: nil
        ))
        
        // Insert new content in reverse order at index 1
        for segment in segments.reversed() {
            switch segment {
            case .text(let text):
                requests.append(GDocsRequest(
                    insertText: GDocsInsertTextRequest(text: text, location: GDocsLocation(index: 1)),
                    deleteContentRange: nil,
                    insertInlineImage: nil,
                    updateEmbeddedObjectProperties: nil
                ))
            case .image(let uri, _):
                requests.append(GDocsRequest(
                    insertText: nil,
                    deleteContentRange: nil,
                    insertInlineImage: GDocsInsertInlineImageRequest(uri: uri, location: GDocsLocation(index: 1)),
                    updateEmbeddedObjectProperties: nil
                ))
            }
        }
        
        return (requests, segments)
    }
    
    private enum ContentSegment {
        case text(String)
        case image(uri: String, assetId: String)
    }
    
    private func parseSegments(content: String, assetMappings: [String: String]) -> [ContentSegment] {
        var segments: [ContentSegment] = []
        let regex = try! NSRegularExpression(pattern: "!\\[\\[(.*?)\\]\\]", options: [])
        let nsString = content as NSString
        let matches = regex.matches(in: content, options: [], range: NSRange(location: 0, length: nsString.length))
        
        var lastEnd = 0
        for match in matches {
            let range = match.range
            if range.location > lastEnd {
                let text = nsString.substring(with: NSRange(location: lastEnd, length: range.location - lastEnd))
                segments.append(.text(text))
            }
            
            let assetId = nsString.substring(with: match.range(at: 1))
            if let uri = assetMappings[assetId] {
                segments.append(.image(uri: uri, assetId: assetId))
            } else {
                // Fallback to raw text if no mapping found
                segments.append(.text(nsString.substring(with: range)))
            }
            lastEnd = range.location + range.length
        }
        
        if lastEnd < nsString.length {
            let text = nsString.substring(with: NSRange(location: lastEnd, length: nsString.length - lastEnd))
            segments.append(.text(text))
        }
        
        return segments
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
                    } else if let inlineObjectElement = element.inlineObjectElement {
                        let objectId = inlineObjectElement.inlineObjectId
                        if let object = doc.inlineObjects?[objectId] {
                            let props = object.inlineObjectProperties.embeddedObject
                            let description = props.description ?? ""
                            if description.hasPrefix("updoc_asset:") {
                                let assetId = description.replacingOccurrences(of: "updoc_asset:", with: "")
                                markdown += "![[\(assetId)]]"
                            } else if let sourceUri = props.imageProperties?.contentUri {
                                markdown += "![\(props.title ?? "image")](\(sourceUri))"
                            }
                        }
                    }
                }
            }
        }
        return markdown
    }
}
