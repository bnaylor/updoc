import XCTest
import SwiftData
@testable import updoc

@MainActor
final class ImageLibraryManagerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: ImageMap.self, configurations: config)
        context = ModelContext(container)
    }
    
    func testSaveAndRetrieveMapping() {
        let assetId = "test-asset-id"
        let driveFileId = "test-drive-file-id"
        let driveUrl = "https://drive.google.com/test"
        
        let manager = ImageLibraryManager.shared
        
        manager.saveMapping(assetId: assetId, driveFileId: driveFileId, driveUrl: driveUrl, in: context)
        
        let retrievedId = manager.getDriveId(for: assetId, in: context)
        XCTAssertEqual(retrievedId, driveFileId)
    }
    
    func testUpdateExistingMapping() {
        let assetId = "test-asset-id"
        let driveFileId1 = "test-drive-file-id-1"
        let driveFileId2 = "test-drive-file-id-2"
        let driveUrl = "https://drive.google.com/test"
        
        let manager = ImageLibraryManager.shared
        
        manager.saveMapping(assetId: assetId, driveFileId: driveFileId1, driveUrl: driveUrl, in: context)
        manager.saveMapping(assetId: assetId, driveFileId: driveFileId2, driveUrl: driveUrl, in: context)
        
        let retrievedId = manager.getDriveId(for: assetId, in: context)
        XCTAssertEqual(retrievedId, driveFileId2)
    }
}
