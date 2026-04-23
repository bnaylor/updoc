import Foundation

public struct Participant: Codable, Sendable {
    public let email: String
    public let name: String?
    
    public init(email: String, name: String?) {
        self.email = email
        self.name = name
    }
}

public struct CalendarEvent: Codable, Identifiable, Sendable {
    public let id: String
    public let summary: String
    public let description: String?
    public let location: String?
    public let start: Date
    public let attendees: [Participant]
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

struct GCalendarOrganizer: Codable {
    let email: String?
    let displayName: String?
}

struct GCalendarCreator: Codable {
    let email: String?
    let displayName: String?
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
    let organizer: GCalendarOrganizer?
    let creator: GCalendarCreator?
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
    let displayName: String?
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
        formatter.timeZone = Calendar.current.timeZone
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
        
        // Save raw data for debugging
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let debugURL = appSupport.appendingPathComponent("updoc/calendar_debug.json")
            try? data.write(to: debugURL)
            print("Saved raw calendar data to: \(debugURL.path)")
        }
        
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
                attendees: {
                    var participants = gEvent.attendees?.compactMap { gAttendee -> Participant? in
                        guard let email = gAttendee.email else { return nil }
                        return Participant(email: email, name: gAttendee.displayName)
                    } ?? []
                    
                    if let organizer = gEvent.organizer, let email = organizer.email {
                        if !participants.contains(where: { $0.email == email }) {
                            participants.append(Participant(email: email, name: organizer.displayName))
                        }
                    }
                    
                    if let creator = gEvent.creator, let email = creator.email {
                        if !participants.contains(where: { $0.email == email }) {
                            participants.append(Participant(email: email, name: creator.displayName))
                        }
                    }
                    
                    return participants
                }(),
                eventType: gEvent.eventType,
                isAllDay: isAllDay,
                attachments: attachments
            )
        }
    }
}
