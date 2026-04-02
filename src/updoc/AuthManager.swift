import Foundation
import Security

public actor AuthManager {
    public static let shared = AuthManager()
    private let service = "com.updoc.auth"
    private let accountAccess = "accessToken"
    private let accountRefresh = "refreshToken"
    
    public init() {}

    public func authorize() async throws -> String {
        // TODO: Implement system browser redirect flow
        return "mock-token"
    }
    
    public func getAccessToken() async throws -> String? {
        return try await getToken(for: accountAccess)
    }
    
    public func getRefreshToken() async throws -> String? {
        return try await getToken(for: accountRefresh)
    }
    
    public func saveTokens(accessToken: String, refreshToken: String?) async throws {
        try await saveToken(accessToken, for: accountAccess)
        if let refreshToken = refreshToken {
            try await saveToken(refreshToken, for: accountRefresh)
        }
    }
    
    private func getToken(for account: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        } else if status == errSecItemNotFound {
            return nil
        } else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
    }
    
    private func saveToken(_ token: String, for account: String) async throws {
        let data = token.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus), userInfo: nil)
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: nil)
        }
    }
}
