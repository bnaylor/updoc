import Foundation

public enum Config {
    public static let clientID = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_ID"] ?? ""
    public static let clientSecret = ProcessInfo.processInfo.environment["GOOGLE_CLIENT_SECRET"] ?? ""
    public static let redirectURI = ProcessInfo.processInfo.environment["GOOGLE_REDIRECT_URI"] ?? ""
}
