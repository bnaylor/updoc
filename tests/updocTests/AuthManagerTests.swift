import Testing
import Foundation
@testable import updoc

struct AuthManagerTests {
    @Test func canSaveAndRetrieveTokens() async throws {
        let manager = AuthManager.shared
        let testToken = "test-access-token-\(UUID().uuidString)"
        await manager.saveTokens(accessToken: testToken, refreshToken: "test-refresh")
        let token = try await manager.getAccessToken()
        #expect(token == testToken)
    }
}
