import Foundation
import SwiftData

@ModelActor
public actor AddressBookManager {
    public func searchContacts(query: String) throws -> [Contact] {
        let descriptor = FetchDescriptor<Contact>(
            predicate: #Predicate { $0.name.contains(query) || $0.username.contains(query) || $0.email.contains(query) },
            sortBy: [SortDescriptor(\Contact.name)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    public func searchPeople(query: String) throws -> [Person] {
        let contacts = try searchContacts(query: query)
        return contacts.map { Person(id: $0.email, name: $0.name, email: $0.email) }
    }
    
    public func addContact(name: String, username: String, email: String, teamsLink: String? = nil) throws {
        let descriptor = FetchDescriptor<Contact>(predicate: #Predicate { $0.email == email })
        let existing = try modelContext.fetch(descriptor)
        if existing.isEmpty {
            let contact = Contact(name: name, username: username, email: email, teamsLink: teamsLink)
            modelContext.insert(contact)
            try modelContext.save()
        }
    }
    
    public func addContacts(emails: [String]) throws {
        for email in emails {
            let username = email.split(separator: "@").first.map(String.init) ?? email
            let name = username.capitalized
            try addContact(name: name, username: username, email: email)
        }
    }
    
    public func scrapeContacts(from text: String) throws {
        // Simple regex to find email addresses as a heuristic for contacts
        let pattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let nsString = text as NSString
        let results = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in results {
            let email = nsString.substring(with: match.range)
            // Assuming username is part before @, and name is capitalized username
            let username = email.split(separator: "@").first.map(String.init) ?? email
            let name = username.capitalized
            
            try addContact(name: name, username: username, email: email)
        }
    }
}
