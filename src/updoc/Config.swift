import Foundation

public enum Config {
    private static let service = "com.example.updoc.config"
    
    nonisolated(unsafe) private static var _cachedClientID: String?
    public static var clientID: String {
        if let cached = _cachedClientID { return cached }
        let value: String
        if let userDefaultsValue = UserDefaults.standard.string(forKey: "googleClientID") {
            value = userDefaultsValue
        } else if let envValue = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"], !envValue.isEmpty {
            value = envValue
        } else {
            value = ""
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        _cachedClientID = trimmed
        return trimmed
    }
    
    nonisolated(unsafe) private static var _cachedClientSecret: String?
    public static var clientSecret: String {
        if let cached = _cachedClientSecret { return cached }
        let value: String
        if let userDefaultsValue = UserDefaults.standard.string(forKey: "googleClientSecret") {
            value = userDefaultsValue
        } else if let envValue = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"], !envValue.isEmpty {
            value = envValue
        } else {
            value = ""
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        _cachedClientSecret = trimmed
        return trimmed
    }
    
    nonisolated(unsafe) private static var _cachedRedirectURI: String?
    public static var redirectURI: String {
        if let cached = _cachedRedirectURI { return cached }
        let value: String
        if let userDefaultsValue = UserDefaults.standard.string(forKey: "googleRedirectURI") {
            value = userDefaultsValue
        } else if let envValue = ProcessInfo.processInfo.environment["GOOGLE_REDIRECT_URI"], !envValue.isEmpty {
            value = envValue
        } else {
            value = ""
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        _cachedRedirectURI = trimmed
        return trimmed
    }
    
    public static func saveCredentials(clientID: String, clientSecret: String, redirectURI: String) {
        let trimmedID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURI = redirectURI.trimmingCharacters(in: .whitespacesAndNewlines)
        
        UserDefaults.standard.set(trimmedID, forKey: "googleClientID")
        UserDefaults.standard.set(trimmedSecret, forKey: "googleClientSecret")
        UserDefaults.standard.set(trimmedURI, forKey: "googleRedirectURI")
        
        // Cleanup old Keychain values if they exist, ignore errors
        try? KeychainHelper.delete(service: service, account: "googleClientID")
        try? KeychainHelper.delete(service: service, account: "googleClientSecret")
        try? KeychainHelper.delete(service: service, account: "googleRedirectURI")
        
        // Update cache
        clearCache()
        _cachedClientID = trimmedID
        _cachedClientSecret = trimmedSecret
        _cachedRedirectURI = trimmedURI
    }
    
    public static func clearCache() {
        _cachedClientID = nil
        _cachedClientSecret = nil
        _cachedRedirectURI = nil
    }
    
    public static var momaAPIURL: String {
        ProcessInfo.processInfo.environment["MOMA_API_URL"] ?? ""
    }
    public static var momaAPIKey: String {
        ProcessInfo.processInfo.environment["MOMA_API_KEY"] ?? ""
    }
}
