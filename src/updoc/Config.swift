import Foundation

public enum Config {
    public static var clientID: String {
        UserDefaults.standard.string(forKey: "googleClientID") ?? ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? ""
    }
    public static var clientSecret: String {
        UserDefaults.standard.string(forKey: "googleClientSecret") ?? ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] ?? ""
    }
    public static var redirectURI: String {
        UserDefaults.standard.string(forKey: "googleRedirectURI") ?? ProcessInfo.processInfo.environment["GOOGLE_REDIRECT_URI"] ?? ""
    }
    
    public static var momaAPIURL: String {
        ProcessInfo.processInfo.environment["MOMA_API_URL"] ?? ""
    }
    public static var momaAPIKey: String {
        ProcessInfo.processInfo.environment["MOMA_API_KEY"] ?? ""
    }
}
