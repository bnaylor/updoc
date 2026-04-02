import Testing
import Foundation
@testable import updoc

struct ServiceTests {
    @Test func gDriveServiceReturnsMockRevision() async throws {
        let service = GDriveService()
        let revision = try await service.getFileRevision(fileId: "test-id")
        #expect(revision == "rev-1")
    }
    
    @Test func gDocsServiceReturnsMockContent() async throws {
        let service = GDocsService()
        let content = try await service.fetchDocContent(docId: "test-id")
        #expect(content == "# Remote Content")
    }

    @Test func gDocsServiceUpdatesContent() async throws {
        let service = GDocsService()
        try await service.updateDocContent(docId: "test-id", content: "# New Content")
        // Success means no error thrown
    }
}
