import Foundation
import AppAuth

public enum KeychainStore {
    private static let service = "com.example.updoc.auth"
    private static let account = "authState"

    public static func save(authState: OIDAuthState) throws {
        let data = try NSKeyedArchiver.archivedData(withRootObject: authState, requiringSecureCoding: false)
        let value = data.base64EncodedString()
        try KeychainHelper.save(service: service, account: account, value: value)
    }

    public static func retrieveAuthState() throws -> OIDAuthState? {
        guard let value = KeychainHelper.read(service: service, account: account),
              let data = Data(base64Encoded: value) else {
            return nil
        }
        return try NSKeyedUnarchiver.unarchivedObject(ofClass: OIDAuthState.self, from: data)
    }

    public static func removeAuthSession() throws {
        try KeychainHelper.delete(service: service, account: account)
    }
}
