import Testing
import Foundation
@testable import updoc

@Suite("GDriveService Tests")
struct GDriveServiceTests {
    
    @Test func gDriveSearchResponseDecodesCorrectly() throws {
        let json = """
        {
            "files": [
                {"id": "folder-id-123", "name": "UpDoc Images", "mimeType": "application/vnd.google-apps.folder"}
            ]
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(GDriveSearchResponse.self, from: json)
        
        #expect(response.files.count == 1)
        #expect(response.files[0].id == "folder-id-123")
        #expect(response.files[0].name == "UpDoc Images")
        #expect(response.files[0].mimeType == "application/vnd.google-apps.folder")
    }
    
    @Test func gDriveFileDecodesCorrectly() throws {
        let json = """
        {
            "id": "file-id-456",
            "name": "test.jpg",
            "mimeType": "image/jpeg"
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let file = try decoder.decode(GDriveFile.self, from: json)
        
        #expect(file.id == "file-id-456")
        #expect(file.name == "test.jpg")
        #expect(file.mimeType == "image/jpeg")
    }

    @Test func gDriveFileMetadataDecodesCorrectly() throws {
        let json = """
        {
            "id": "file-id-789",
            "ownedByMe": true
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(GDriveFileMetadata.self, from: json)
        
        #expect(metadata.id == "file-id-789")
        #expect(metadata.ownedByMe == true)
    }

    /*
    @Test func gDriveServiceFailsWhenNotAuthenticated() async throws {
        // Given GDriveService is initialized
        let service = GDriveService()
        
        // When calling methods (which use AuthManager.shared.getAccessToken())
        // Then it should throw because AuthManager is likely not authenticated in test environment
        await #expect(throws: (any Error).self) {
            _ = try await service.getOrCreateFolder(named: "Test Folder")
        }
        
        await #expect(throws: (any Error).self) {
            _ = try await service.uploadFile(data: Data(), filename: "test.jpg", parentId: "parent-id")
        }
    }
    */
}
