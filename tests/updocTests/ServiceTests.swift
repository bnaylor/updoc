import Testing
import Foundation
@testable import updoc

struct ServiceTests {
    @Test func gDriveServiceFailsWhenNotAuthenticated() async throws {
        let service = GDriveService()
        await #expect(throws: Error.self) {
            try await service.getFileRevision(fileId: "test-id")
        }
    }
    
    @Test func gDocsServiceFailsWhenNotAuthenticated() async throws {
        let service = GDocsService()
        await #expect(throws: Error.self) {
            _ = try await service.fetchDocContent(docId: "test-id")
        }
    }

    @Test func gDocsServiceUpdateFailsWhenNotAuthenticated() async throws {
        let service = GDocsService()
        let dummyDoc = GDocsDocument(
            documentId: "test-id",
            revisionId: "rev-1",
            title: "Test",
            body: GDocsBody(content: []),
            inlineObjects: nil
        )
        await #expect(throws: Error.self) {
            try await service.updateDocContent(docId: "test-id", content: "# New Content", baseDocument: dummyDoc)
        }
    }

    @Test func gDocsServiceInsertImageFailsWhenNotAuthenticated() async throws {
        let service = GDocsService()
        await #expect(throws: Error.self) {
            try await service.insertImage(docId: "test-id", index: 1, uri: "https://example.com/image.png", assetId: "asset-123")
        }
    }
}
