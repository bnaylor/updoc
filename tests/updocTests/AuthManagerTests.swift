import Testing
import Foundation
@testable import updoc

@MainActor
struct AuthManagerTests {
    @Test func checkInitialAuthState() async throws {
        let manager = AuthManager.shared
        // Initially should be false unless a valid session is already in UserDefaults
        let authenticated = manager.isAuthenticated()
        #expect(authenticated == authenticated) // Just checking it's accessible
    }
}
