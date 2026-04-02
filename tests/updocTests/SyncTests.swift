import Testing
import Foundation
import SwiftData
@testable import updoc

@MainActor
struct SyncTests {
    @Test func syncCoordinatorMergesContentOnConflict() async throws {
        let coordinator = SyncCoordinator()
        let local = "# Local"
        let remote = "# Remote"
        let merged = coordinator.merge(local: local, remote: remote)
        
        #expect(merged.contains("# Local"))
        #expect(merged.contains("# Remote"))
    }
}
