import Foundation
import SwiftData

@Model
public class Contact {
    public var name: String
    public var username: String
    @Attribute(.unique) public var email: String
    public var teamsLink: String?
    public var avatarData: Data? // For caching avatar picture
    
    public init(name: String, username: String, email: String, teamsLink: String? = nil, avatarData: Data? = nil) {
        self.name = name
        self.username = username
        self.email = email
        self.teamsLink = teamsLink
        self.avatarData = avatarData
    }
}

extension Contact: Hashable, Identifiable {
    public static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.email == rhs.email
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(email)
    }
    public var id: String { email }
}
