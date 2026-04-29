import Testing
import Foundation
@testable import updoc

final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            fatalError("Handler is not set.")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

struct MockAuthProvider: AuthProvider {
    func getAccessToken() async throws -> String {
        return "mock-token"
    }
}

@Suite("GDocs Conflict Resolution Tests")
@MainActor
struct GDocsConflictTests {
    
    private let mockSession: URLSession
    private let service: GDocsService
    
    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: configuration)
        service = GDocsService(session: mockSession, authProvider: MockAuthProvider())
    }
    
    @Test func updateDocRetriesOnRevisionMismatch() async throws {
        let docId = "test-doc-id"
        let baseDoc = GDocsDocument(
            documentId: docId,
            revisionId: "rev-1",
            title: "Test",
            body: GDocsBody(content: []),
            inlineObjects: nil,
            lists: nil
        )
        
        let updatedDoc = GDocsDocument(
            documentId: docId,
            revisionId: "rev-2", // New revision
            title: "Test",
            body: GDocsBody(content: [
                GDocsStructuralElement(startIndex: 1, endIndex: 13, paragraph: GDocsParagraph(elements: [
                    GDocsParagraphElement(startIndex: 1, endIndex: 13, textRun: GDocsTextRun(content: "Remote Change\n", textStyle: nil), inlineObjectElement: nil, person: nil, richLink: nil, dateElement: nil)
                ]))
            ]),
            inlineObjects: nil,
            lists: nil
        )
        
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            
            if request.url?.absoluteString.contains("batchUpdate") == true {
                if requestCount == 1 {
                    // First attempt: simulate revision mismatch (400)
                    let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
                    let errorJson = "{\"error\": {\"message\": \"revisionId mismatch\"}}".data(using: .utf8)!
                    return (response, errorJson)
                } else if requestCount == 3 {
                    // Third request: simulate successful update after re-fetch
                    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                    let successResponse = GDocsBatchUpdateResponse(replies: [
                        GDocsReply(insertInlineImage: nil),
                        GDocsReply(insertInlineImage: nil)
                    ])
                    let data = try! JSONEncoder().encode(successResponse)
                    return (response, data)
                }
            } else if request.url?.absoluteString.contains("documents/\(docId)") == true && request.httpMethod == "GET" {
                // Second request: re-fetch doc content
                if requestCount == 2 || requestCount == 4 {
                    let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                    let data = try! JSONEncoder().encode(updatedDoc)
                    return (response, data)
                }
            }
            
            fatalError("Unexpected request #\(requestCount): \(request)")
        }
        
        // When
        try await service.updateDocContent(docId: docId, content: "Local Change", baseDocument: baseDoc)
        
        // Then
        // 1. Initial update (fail)
        // 2. Fetch doc (success)
        // 3. Retry update (success)
        // 4. Final fetch for revision (success)
        #expect(requestCount == 4)
    }
}
