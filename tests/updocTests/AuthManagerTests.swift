import Testing
import Foundation
@testable import updoc

struct AuthManagerTests {
    @Test func canSaveAndRetrieveTokens() async throws {
        let manager = AuthManager.shared
        try await manager.saveTokens(accessToken: "test-access", refreshToken: "test-refresh")
        
        let accessToken = try await manager.getAccessToken()
        #expect(accessToken == "test-access")
        
        let refreshToken = try await manager.getRefreshToken()
        #expect(refreshToken == "test-refresh")
    }
}
