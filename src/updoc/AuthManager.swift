import Foundation
import AppKit
import AuthenticationServices
import GTMAppAuth
@preconcurrency import AppAuth
import Observation

@MainActor
@Observable
public final class AuthManager: NSObject, @unchecked Sendable {
    public static let shared = AuthManager()
    
    private var authState: OIDAuthState?
    public private(set) var userEmail: String?
    private var isAuthorizing = false
    private var activeFlow: OIDExternalUserAgentSession?
    
    private static let keychainService = "com.example.updoc.auth"
    private static let keychainAccount = "authState"

    private override init() {
        super.init()
        loadAuthState()
    }
    
    public func load() async {
        // Just triggers the init-time loading or refreshes if needed
        if let authState = authState {
            self.userEmail = authState.lastTokenResponse?.idToken != nil ? 
                AuthSession(authState: authState).userEmail : nil
        }
    }
    
    public func authorize(in window: NSWindow) async throws {
        guard !isAuthorizing else { return }
        isAuthorizing = true
        defer { isAuthorizing = false }
        
        let clientID = Config.clientID
        let clientSecret = Config.clientSecret
        let redirectURIString = Config.redirectURI
        
        guard let redirectURL = URL(string: redirectURIString) else {
            throw NSError(domain: "AuthManager", code: -5, userInfo: [NSLocalizedDescriptionKey: "Invalid redirect URI"])
        }
        
        let issuer = URL(string: "https://accounts.google.com")!
        let configuration = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OIDServiceConfiguration, Error>) in
            OIDAuthorizationService.discoverConfiguration(forIssuer: issuer) { config, error in
                if let error = error { continuation.resume(throwing: error) }
                else if let config = config { continuation.resume(returning: config) }
                else { continuation.resume(throwing: NSError(domain: "AuthManager", code: -1)) }
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
                "https://www.googleapis.com/auth/drive",
                "https://www.googleapis.com/auth/calendar.events.readonly"
            ],
            redirectURL: redirectURL,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )
        
        let externalUserAgent = OIDExternalUserAgentMac(presenting: window)
        
        let finalAuthState = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<OIDAuthState, Error>) in
            self.activeFlow = OIDAuthState.authState(byPresenting: request, externalUserAgent: externalUserAgent) { authState, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let authState = authState {
                    continuation.resume(returning: authState)
                } else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: -7))
                }
            }
        }
        
        self.activeFlow = nil
        self.setAuthState(finalAuthState)
    }
    
    public func signOut() {
        self.setAuthState(nil)
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
        if let authState = authState {
            self.userEmail = AuthSession(authState: authState).userEmail
            saveAuthState(authState)
        } else {
            self.userEmail = nil
            removeAuthSession()
        }
    }
    
    private func saveAuthState(_ authState: OIDAuthState) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: false)
            let value = data.base64EncodedString()
            try KeychainHelper.save(service: Self.keychainService, account: Self.keychainAccount, value: value)
        } catch {
            print("AuthManager: Failed to save auth state: \(error)")
        }
    }
    
    private func loadAuthState() {
        if let value = KeychainHelper.read(service: Self.keychainService, account: Self.keychainAccount),
           let data = Data(base64Encoded: value) {
            do {
                self.authState = try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
                if let authState = self.authState {
                    self.userEmail = AuthSession(authState: authState).userEmail
                }
            } catch {
                print("AuthManager: Failed to load auth state: \(error)")
            }
        }
    }
    
    private func removeAuthSession() {
        try? KeychainHelper.delete(service: Self.keychainService, account: Self.keychainAccount)
    }
}
