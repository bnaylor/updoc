import Foundation

public enum Config {
    private static let service = "com.example.updoc.config"
    
    nonisolated(unsafe) private static var _cachedClientID: String?
    public static var clientID: String {
        if let cached = _cachedClientID { return cached }
        let value: String
        if let keychainValue = KeychainHelper.read(service: service, account: "googleClientID") {
            print("Config: Loaded clientID from Keychain")
            value = keychainValue
        } else if let userDefaultsValue = UserDefaults.standard.string(forKey: "googleClientID") {
            print("Config: Loaded clientID from UserDefaults")
            value = userDefaultsValue
        } else if let envValue = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"], !envValue.isEmpty {
            print("Config: Loaded clientID from Environment")
            value = envValue
        } else {
            print("Config: clientID is EMPTY")
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
        if let keychainValue = KeychainHelper.read(service: service, account: "googleClientSecret") {
            print("Config: Loaded clientSecret from Keychain")
            value = keychainValue
        } else if let userDefaultsValue = UserDefaults.standard.string(forKey: "googleClientSecret") {
            print("Config: Loaded clientSecret from UserDefaults")
            value = userDefaultsValue
        } else if let envValue = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"], !envValue.isEmpty {
            print("Config: Loaded clientSecret from Environment")
            value = envValue
        } else {
            print("Config: clientSecret is EMPTY")
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
        if let keychainValue = KeychainHelper.read(service: service, account: "googleRedirectURI") {
            print("Config: Loaded redirectURI from Keychain")
            value = keychainValue
        } else if let userDefaultsValue = UserDefaults.standard.string(forKey: "googleRedirectURI") {
            print("Config: Loaded redirectURI from UserDefaults")
            value = userDefaultsValue
        } else if let envValue = ProcessInfo.processInfo.environment["GOOGLE_REDIRECT_URI"], !envValue.isEmpty {
            print("Config: Loaded redirectURI from Environment")
            value = envValue
        } else {
            print("Config: redirectURI is EMPTY")
            value = ""
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        _cachedRedirectURI = trimmed
        return trimmed
    }
    
    public static func saveCredentials(clientID: String, clientSecret: String, redirectURI: String) throws {
        let trimmedID = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSecret = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURI = redirectURI.trimmingCharacters(in: .whitespacesAndNewlines)
        
        try KeychainHelper.save(service: service, account: "googleClientID", value: trimmedID)
        try KeychainHelper.save(service: service, account: "googleClientSecret", value: trimmedSecret)
        try KeychainHelper.save(service: service, account: "googleRedirectURI", value: trimmedURI)
        
        // Update cache
        clearCache()
        _cachedClientID = trimmedID
        _cachedClientSecret = trimmedSecret
        _cachedRedirectURI = trimmedURI
        
        // Cleanup old UserDefaults values if they exist
        UserDefaults.standard.removeObject(forKey: "googleClientID")
        UserDefaults.standard.removeObject(forKey: "googleClientSecret")
        UserDefaults.standard.removeObject(forKey: "googleRedirectURI")
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
