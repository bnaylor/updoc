import Foundation

public protocol AuthProvider: Sendable {
    func getAccessToken() async throws -> String
}

extension AuthManager: AuthProvider {}

public struct GDocsService: Sendable {
    private let session: URLSession
    private let authProvider: AuthProvider?

    public init(session: URLSession = .shared, authProvider: AuthProvider? = nil) {
        self.session = session
        self.authProvider = authProvider
    }
    
    private func getAccessToken() async throws -> String {
        if let authProvider = authProvider {
            return try await authProvider.getAccessToken()
        }
        return try await AuthManager.shared.getAccessToken()
    }
    
    public func fetchDocContent(docId: String) async throws -> (markdown: String, document: GDocsDocument) {
        let token = try await getAccessToken()
        let url = URL(string: "https://docs.googleapis.com/v1/documents/\(docId)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch doc: \(errorBody)"])
        }
        
        let doc = try JSONDecoder().decode(GDocsDocument.self, from: data)
        return (markdown: convertToMarkdown(doc), document: doc)
    }
    
    @discardableResult
    public func updateDocContent(docId: String, content: String, baseDocument: GDocsDocument, assetMappings: [String: String] = [:]) async throws -> (revisionId: String, mergedContent: String?) {
        var currentBase = baseDocument
        var currentContent = content
        var attempts = 0
        let maxAttempts = 5
        var wasMerged = false

        while attempts < maxAttempts {
            do {
                try await performUpdate(docId: docId, content: currentContent, baseDocument: currentBase, assetMappings: assetMappings)
                // Re-fetch to get the latest revision ID after the successful push
                let (_, finalDoc) = try await fetchDocContent(docId: docId)
                return (revisionId: finalDoc.revisionId ?? "", mergedContent: wasMerged ? currentContent : nil)
            } catch let error as NSError {
                let errorBody = error.userInfo[NSLocalizedDescriptionKey] as? String ?? ""
                let isRevisionMismatch = error.code == 400 && (errorBody.contains("revision ID") || errorBody.contains("revisionId"))

                if isRevisionMismatch && attempts < maxAttempts - 1 {
                    attempts += 1
                    wasMerged = true

                    // Exponential backoff: 500ms, 1s, 2s, 4s
                    let delaySeconds = 0.5 * pow(2.0, Double(attempts - 1))
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))

                    // Re-fetch document to get latest revision and remote content
                    let (remoteMarkdown, remoteDoc) = try await fetchDocContent(docId: docId)

                    // Rebase: merge local changes with remote updates
                    let localBaseMarkdown = convertToMarkdown(baseDocument)
                    currentContent = merge(base: localBaseMarkdown, local: currentContent, remote: remoteMarkdown)
                    currentBase = remoteDoc

                    continue
                }
                throw error
            }
        }
        return ("", nil) // Should not be reached
    }

    private func performUpdate(docId: String, content: String, baseDocument: GDocsDocument, assetMappings: [String: String]) async throws {
        let token = try await getAccessToken()
        let formatter = GDocsMarkdownFormatter()
        let formatted = formatter.format(content, assetMappings: assetMappings)
        
        // STAGE 1: Replacement (Establish stable baseline)
        var replaceRequests: [GDocsRequest] = []
        let lastElement = baseDocument.body.content.last
        let endIndex = lastElement?.endIndex ?? 2
        
        if endIndex > 2 {
            replaceRequests.append(GDocsRequest(
                deleteContentRange: GDocsDeleteContentRangeRequest(range: GDocsRange(startIndex: 1, endIndex: endIndex - 1))
            ))
        }
        
        if !formatted.cleanText.isEmpty {
            replaceRequests.append(GDocsRequest(
                insertText: GDocsInsertTextRequest(text: formatted.cleanText, location: GDocsLocation(index: 1))
            ))
        }
        
        if !replaceRequests.isEmpty {
            let replaceBatch = GDocsBatchUpdateRequest(requests: replaceRequests, writeControl: GDocsWriteControl(requiredRevisionId: baseDocument.revisionId))
            let replaceData = try JSONEncoder().encode(replaceBatch)
            try await sendBatchUpdate(docId: docId, data: replaceData, token: token)
        }
        
        // Re-fetch to get fresh indices and revision ID
        let (_, structureDoc) = try await fetchDocContent(docId: docId)
        
        // STAGE 2: Structure (Paragraph Styles & Bullets)
        let structureRequests = formatted.requests.filter { $0.updateParagraphStyle != nil || $0.createBullets != nil }
        if !structureRequests.isEmpty {
            let structureBatch = GDocsBatchUpdateRequest(requests: structureRequests, writeControl: GDocsWriteControl(requiredRevisionId: structureDoc.revisionId))
            let structureData = try JSONEncoder().encode(structureBatch)
            try await sendBatchUpdate(docId: docId, data: structureData, token: token)
        }
        
        // Re-fetch again for the final stage
        let (_, styleDoc) = try await fetchDocContent(docId: docId)
        
        // STAGE 3: Inline Styles & Images
        var styleRequests = formatted.requests.filter { $0.updateTextStyle != nil }
        let imageRequests = formatted.imageSegments.reversed().map { (index, uri, assetId) in
            GDocsRequest(
                insertInlineImage: GDocsInsertInlineImageRequest(uri: uri, location: GDocsLocation(index: index))
            )
        }
        styleRequests.append(contentsOf: imageRequests)
        
        if !styleRequests.isEmpty {
            let styleBatch = GDocsBatchUpdateRequest(requests: styleRequests, writeControl: GDocsWriteControl(requiredRevisionId: styleDoc.revisionId))
            let styleData = try JSONEncoder().encode(styleBatch)
            let responseData = try await sendBatchUpdate(docId: docId, data: styleData, token: token)
            
            // Tag images
            let batchResponse = try JSONDecoder().decode(GDocsBatchUpdateResponse.self, from: responseData)
            var tagRequests: [GDocsRequest] = []
            let imageReplyOffset = styleRequests.count - formatted.imageSegments.count
            
            for (idx, segment) in formatted.imageSegments.reversed().enumerated() {
                let replyIdx = imageReplyOffset + idx
                if let objectId = batchResponse.replies[replyIdx].insertInlineImage?.objectId {
                    tagRequests.append(GDocsRequest(
                        updateEmbeddedObjectProperties: GDocsUpdateEmbeddedObjectPropertiesRequest(
                            objectId: objectId,
                            properties: GDocsEmbeddedObjectProperties(description: "updoc_asset:\(segment.assetId)"),
                            fields: "description"
                        )
                    ))
                }
            }
            
            if !tagRequests.isEmpty {
                let tagBatch = GDocsBatchUpdateRequest(requests: tagRequests)
                let tagData = try JSONEncoder().encode(tagBatch)
                _ = try? await sendBatchUpdate(docId: docId, data: tagData, token: token)
            }
        }
    }

    @discardableResult
    private func sendBatchUpdate(docId: String, data: Data, token: String) async throws -> Data {
        var request = URLRequest(url: URL(string: "https://docs.googleapis.com/v1/documents/\(docId):batchUpdate")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            let payloadString = String(data: data, encoding: .utf8) ?? "Could not decode payload"
            print("GDocs BatchUpdate failed. Status: \(httpResponse.statusCode)")
            print("Error: \(errorBody)")
            print("Payload: \(payloadString)")
            throw NSError(domain: "GDocsService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "BatchUpdate failed: \(errorBody)"])
        }
        return responseData
    }

    private func merge(base: String, local: String, remote: String) -> String {
        if local == base { return remote }
        if remote == base { return local }
        // Simple strategy: prefer local for conflicts for now
        return local
    }
    
    // Type alias for easier reading
    private typealias ImageSegment = GDocsMarkdownFormatter.ImageSegment
    
    public func insertImage(docId: String, index: Int, uri: String, assetId: String) async throws {
        let token = try await getAccessToken()
        let insertRequest = GDocsRequest(
            insertText: nil,
            deleteContentRange: nil,
            insertInlineImage: GDocsInsertInlineImageRequest(uri: uri, location: GDocsLocation(index: index)),
            updateEmbeddedObjectProperties: nil
        )
        
        let batchRequest = GDocsBatchUpdateRequest(requests: [insertRequest])
        let batchData = try JSONEncoder().encode(batchRequest)
        
        var request = URLRequest(url: URL(string: "https://docs.googleapis.com/v1/documents/\(docId):batchUpdate")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = batchData
        
        let (data, response) = try await session.data(for: request)
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
        let token = try await getAccessToken()
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
        
        let (data, response) = try await session.data(for: request)
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
