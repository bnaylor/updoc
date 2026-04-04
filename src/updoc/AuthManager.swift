import Foundation
import AppKit
import AuthenticationServices
import GTMAppAuth
@preconcurrency import AppAuth

@MainActor
public final class AuthManager: NSObject, @unchecked Sendable {
    public static let shared = AuthManager()
    
    private var authState: OIDAuthState?
    private var isAuthorizing = false
    private var activeFlow: OIDExternalUserAgentSession?
    
    private override init() {
        super.init()
        loadAuthState()
    }
    
    public func authorize(in window: NSWindow) async throws {
        guard !isAuthorizing else {
            print("AuthManager: Authorization already in progress")
            return
        }
        isAuthorizing = true
        defer { isAuthorizing = false }
        
        let clientID = Config.clientID
        let clientSecret = Config.clientSecret
        let redirectURIString = Config.redirectURI
        
        print("AuthManager: Starting flow for \(clientID.prefix(10))..."); fflush(stdout)
        
        guard let redirectURL = URL(string: redirectURIString) else {
            throw NSError(domain: "AuthManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid redirect URI"])
        }
        
        print("AuthManager: Discovering configuration..."); fflush(stdout)
        let issuer = URL(string: "https://accounts.google.com")!
        
        let configuration = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OIDServiceConfiguration, Error>) in
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { config, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let config = config {
                    continuation.resume(returning: config)
                } else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Discovery failed"]))
                }
            }
        }
        
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: clientID,
            clientSecret: clientSecret,
            scopes: [
                "openid",
                "email",
                "https://www.googleapis.com/auth/documents",
                "https://www.googleapis.com/auth/drive.metadata.readonly",
                "https://www.googleapis.com/auth/drive.file"
            ],
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )
        
        print("AuthManager: Starting auth session via AppAuth UI..."); fflush(stdout)
        
        // Use the built-in AppAuth external user agent for macOS
        let externalUserAgent = OIDExternalUserAgentMac(presenting: window)
        
        let finalAuthState = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OIDAuthState, Error>) in
            // CRITICAL: We MUST hold the returned session, otherwise the flow is dropped immediately.
            self.activeFlow = OIDAuthState.authState(byPresenting: request, externalUserAgent: externalUserAgent) { authState, error in
                if let error = error {
                    print("AuthManager: Auth flow error: \(error.localizedDescription)"); fflush(stdout)
                    continuation.resume(throwing: error)
                } else if let authState = authState {
                    print("AuthManager: Auth flow SUCCESS"); fflush(stdout)
                    continuation.resume(returning: authState)
                } else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: -7, userInfo: [NSLocalizedDescriptionKey: "Auth flow returned nil"]))
                }
            }
        }
        
        self.activeFlow = nil
        self.setAuthState(finalAuthState)
    }
    
    public func getAccessToken() async throws -> String {
        guard let authState = authState else { throw NSError(domain: "AuthManager", code: -3) }
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            authState.performAction { token, _, error in
                if let error = error { continuation.resume(throwing: error) }
                else if let token = token { continuation.resume(returning: token) }
                else { continuation.resume(throwing: NSError(domain: "AuthManager", code: -4)) }
            }
        }
    }
    
    public func isAuthenticated() -> Bool {
        return authState?.isAuthorized ?? false
    }
    
    private func setAuthState(_ authState: OIDAuthState?) {
        self.authState = authState
        saveAuthState()
    }
    
    private func saveAuthState() {
        if let authState = authState {
            do {
                try KeychainStore.save(authState: authState)
            } catch {
                print("AuthManager: Failed to save auth state: \(error)")
            }
        } else {
            try? KeychainStore.removeAuthSession()
        }
    }
    
    private func loadAuthState() {
        do {
            self.authState = try KeychainStore.retrieveAuthState()
        } catch {
            // No existing auth state
        }
    }
}
