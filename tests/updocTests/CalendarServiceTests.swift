import Testing
import Foundation
@testable import updoc

struct CalendarServiceTests {
    @Test func fetchEventsFailsWhenNotAuthenticated() async throws {
        let service = GCalendarService.shared
        // In unit tests, we are not authenticated, so it should throw
        await #expect(throws: Error.self) {
            try await service.fetchTodaysEvents()
        }
    }
}
