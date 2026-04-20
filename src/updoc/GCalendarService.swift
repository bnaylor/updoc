import Foundation

public struct CalendarEvent: Codable, Identifiable, Sendable {
    public let id: String
    public let summary: String
    public let description: String?
    public let location: String?
    public let start: Date
    public let attendees: [String]
    public let eventType: String?
    public let isAllDay: Bool
    public let attachments: [CalendarAttachment]
}

public struct CalendarAttachment: Codable, Sendable {
    public let fileUrl: String
    public let title: String
}

struct GCalendarResponse: Codable {
    let items: [GCalendarEvent]
}

struct GCalendarEvent: Codable {
    let id: String
    let summary: String?
    let description: String?
    let location: String?
    let start: GCalendarTime?
    let attendees: [GCalendarAttendee]?
    let eventType: String?
    let attachments: [GCalendarAttachment]?
}

struct GCalendarAttachment: Codable {
    let fileUrl: String?
    let title: String?
}

struct GCalendarTime: Codable {
    let dateTime: String?
    let date: String?
}

struct GCalendarAttendee: Codable {
    let email: String?
}

public actor GCalendarService {
    public static let shared = GCalendarService()
    
    public init() {}
    
    public func fetchTodaysEvents() async throws -> [CalendarEvent] {
        let token = try await AuthManager.shared.getAccessToken()
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startOfDay)
        let timeMax = formatter.string(from: endOfDay)
        
        let urlString = "https://www.googleapis.com/calendar/v3/calendars/primary/events?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true&orderBy=startTime"
        let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)!
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "GCalendarService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch calendar events: \(errorBody)"])
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let calendarResponse = try decoder.decode(GCalendarResponse.self, from: data)
        
        return calendarResponse.items.compactMap { gEvent in
            guard let startStr = gEvent.start?.dateTime ?? gEvent.start?.date else { return nil }
            
            let startDate: Date
            if let date = formatter.date(from: startStr) {
                startDate = date
            } else {
                // Fallback for all-day events (YYYY-MM-DD)
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "yyyy-MM-dd"
                startDate = dayFormatter.date(from: startStr) ?? Date()
            }
            
            let isAllDay = gEvent.start?.dateTime == nil && gEvent.start?.date != nil
            
            let attachments = gEvent.attachments?.compactMap { gAttachment -> CalendarAttachment? in
                guard let url = gAttachment.fileUrl, let title = gAttachment.title else { return nil }
                return CalendarAttachment(fileUrl: url, title: title)
            } ?? []
            
            return CalendarEvent(
                id: gEvent.id,
                summary: gEvent.summary ?? "(No Title)",
                description: gEvent.description,
                location: gEvent.location,
                start: startDate,
                attendees: gEvent.attendees?.compactMap { $0.email } ?? [],
                eventType: gEvent.eventType,
                isAllDay: isAllDay,
                attachments: attachments
            )
        }
    }
}
