import XCTest
import SwiftData
@testable import updoc

@MainActor
final class SyncConflictTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var coordinator: SyncCoordinator!
    
    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(for: Note.self, ActionItem.self, ImageMap.self, configurations: config)
        context = container.mainContext
        coordinator = SyncCoordinator()
    }
    
    func testConflictErrorEquality() {
        let error1 = SyncError.conflict(local: "a", remote: "b", remoteRevision: "r1")
        let error2 = SyncError.conflict(local: "a", remote: "b", remoteRevision: "r1")
        let error3 = SyncError.conflict(local: "a", remote: "c", remoteRevision: "r1")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
}
