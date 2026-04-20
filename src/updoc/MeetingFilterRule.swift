import Foundation
import SwiftData

@Model
public class MeetingFilterRule {
    public var id: UUID
    public var titlePattern: String?
    public var descriptionPattern: String?
    public var participantPattern: String?
    public var timeRange: String?
    public var daysOfWeek: [Int]?
    public var isAllDay: Bool?
    public var eventType: String?
    
    public init(id: UUID = UUID(),
                titlePattern: String? = nil,
                descriptionPattern: String? = nil,
                participantPattern: String? = nil,
                timeRange: String? = nil,
                daysOfWeek: [Int]? = nil,
                isAllDay: Bool? = nil,
                eventType: String? = nil) {
        self.id = id
        self.titlePattern = titlePattern
        self.descriptionPattern = descriptionPattern
        self.participantPattern = participantPattern
        self.timeRange = timeRange
        self.daysOfWeek = daysOfWeek
        self.isAllDay = isAllDay
        self.eventType = eventType
    }
}
