import Foundation
import AppKit
import AuthenticationServices
import GTMAppAuth
import AppAuth

@MainActor
public class AuthManager: NSObject, ASWebAuthenticationPresentationContextProviding {
    public static let shared = AuthManager()
    
    private var authState: OIDAuthState?
    private let keychainKey = "updoc.authState"
    private var currentSession: ASWebAuthenticationSession?
    
    private override init() {
        super.init()
        loadAuthState()
    }
    
    public func authorize(in window: NSWindow) async throws {
        let configuration = AuthSession.configurationForGoogle()
        
        let request = OIDAuthorizationRequest(
            configuration: configuration,
            clientId: Config.clientID,
            clientSecret: Config.clientSecret,
            scopes: [
                "https://www.googleapis.com/auth/documents",
                "https://www.googleapis.com/auth/drive.metadata.readonly",
                "https://www.googleapis.com/auth/calendar.events.readonly"
            ],
            redirectURL: URL(string: Config.redirectURI)!,
            responseType: OIDResponseTypeCode,
            additionalParameters: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: request.authorizationRequestURL(),
                callbackURLScheme: URL(string: Config.redirectURI)?.scheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No callback URL"]))
                    return
                }
                
                // Resume AppAuth flow with the callback URL
                guard let queryComponent = OIDURLQueryComponent(url: callbackURL) else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to parse callback URL"]))
                    return
                }
                
                let response = OIDAuthorizationResponse(request: request, parameters: queryComponent.dictionaryValue)
                
                guard let tokenRequest = response.tokenExchangeRequest() else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create token request"]))
                    return
                }
                
                OIDAuthorizationService.perform(tokenRequest) { tokenResponse, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let tokenResponse = tokenResponse {
                        let authState = OIDAuthState(authorizationResponse: response, tokenResponse: tokenResponse)
                        self.setAuthState(authState)
                        continuation.resume()
                    }
                }
            }
            
            session.presentationContextProvider = self
            session.start()
            self.currentSession = session
        }
    }
    
    public func getAccessToken() async throws -> String {
        guard let authState = authState else {
            throw NSError(domain: "AuthManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            authState.performAction { accessToken, _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let accessToken = accessToken {
                    continuation.resume(returning: accessToken)
                } else {
                    continuation.resume(throwing: NSError(domain: "AuthManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "No access token"]))
                }
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
                let data = try NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: false)
                UserDefaults.standard.set(data, forKey: keychainKey)
            } catch {
                print("Failed to save auth state: \(error)")
            }
        } else {
            UserDefaults.standard.removeObject(forKey: keychainKey)
        }
    }
    
    private func loadAuthState() {
        if let data = UserDefaults.standard.data(forKey: keychainKey) {
            do {
                if let authState = try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data) {
                    self.authState = authState
                }
            } catch {
                print("Failed to load auth state: \(error)")
            }
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApp.keyWindow ?? NSWindow()
    }
}
