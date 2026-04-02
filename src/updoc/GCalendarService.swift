import Foundation

public struct CalendarEvent: Codable, Identifiable, Sendable {
    public let id: String
    public let summary: String
    public let description: String?
    public let location: String?
    public let start: Date
    public let attendees: [String]
}

public actor GCalendarService {
    public static let shared = GCalendarService()
    
    public init() {}
    
    public func fetchTodaysEvents() async throws -> [CalendarEvent] {
        // TODO: Implement Google Calendar API call (for now return mock)
        return [
            CalendarEvent(
                id: "1",
                summary: "updoc Architecture Sync",
                description: "Design sync",
                location: "g.co/doc/abc",
                start: .now,
                attendees: ["bnaylor@google.com", "gemini@google.com"]
            )
        ]
    }
}
