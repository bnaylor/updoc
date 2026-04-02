import Testing
import Foundation
@testable import updoc

struct CalendarServiceTests {
    @Test func canFetchMockEvents() async throws {
        let service = GCalendarService.shared
        let events = try await service.fetchTodaysEvents()
        #expect(events.count > 0)
        #expect(events.first?.summary == "updoc Architecture Sync")
    }
}
