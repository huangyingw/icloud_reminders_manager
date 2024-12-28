import XCTest
import EventKit
@testable import icloud_reminders_manager

final class CalendarManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var calendarManager: CalendarManager!
    var defaultCalendar: EKCalendar!
    
    override func setUp() async throws {
        try await super.setUp()
        eventStore = MockEventStore()
        eventStore.shouldGrantAccess = true
        calendarManager = CalendarManager(eventStore: eventStore)
        
        // Setup mock source
        let mockSource = MockSource(sourceType: .local)
        eventStore.mockSources = [mockSource]
        
        // Setup calendar
        defaultCalendar = EKCalendar(for: .event, eventStore: eventStore)
        defaultCalendar.source = mockSource
        defaultCalendar.title = "Test Calendar"
        try eventStore.saveCalendar(defaultCalendar, commit: true)
    }
    
    override func tearDown() async throws {
        eventStore = nil
        calendarManager = nil
        defaultCalendar = nil
        try await super.tearDown()
    }
    
    func testRequestAccess() async throws {
        let granted = try await calendarManager.requestAccess()
        XCTAssertTrue(granted)
        
        eventStore.shouldGrantAccess = false
        let denied = try await calendarManager.requestAccess()
        XCTAssertFalse(denied)
    }
    
    func testCreateEventFromReminder() async throws {
        let reminder = createTestReminder(withTitle: "Test Reminder", dueDate: Date())
        let event = try await calendarManager.createEventFromReminder(reminder)
        
        XCTAssertEqual(event.title, reminder.title)
        XCTAssertEqual(event.startDate, reminder.dueDateComponents?.date)
        XCTAssertEqual(event.notes, reminder.notes)
        XCTAssertEqual(event.calendar, defaultCalendar)
        
        // Cleanup
        try eventStore.remove(event, span: .thisEvent)
        try eventStore.remove(reminder, commit: true)
    }
    
    func testMoveEventToCurrentWeek() async throws {
        let now = Date()
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: now)!
        
        let event = createTestEvent(withTitle: "Future Meeting", startDate: nextWeek)
        try eventStore.save(event, span: .thisEvent)
        
        let movedEvent = try await calendarManager.moveEventToCurrentWeek(event)
        
        // Verify the event was moved to the current week
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.weekOfYear, from: movedEvent.startDate),
                      calendar.component(.weekOfYear, from: now))
        XCTAssertEqual(calendar.component(.year, from: movedEvent.startDate),
                      calendar.component(.year, from: now))
        
        // Cleanup
        try eventStore.remove(movedEvent, span: .thisEvent)
    }
    
    // MARK: - Helper Methods
    
    private func createTestReminder(withTitle title: String, dueDate: Date) -> EKReminder {
        let reminder = eventStore.createMockReminder()
        reminder.title = title
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        reminder.calendar = defaultCalendar
        try? eventStore.save(reminder, commit: true)
        return reminder
    }
    
    private func createTestEvent(withTitle title: String, startDate: Date) -> EKEvent {
        let event = eventStore.createMockEvent()
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        event.calendar = defaultCalendar
        return event
    }
}

// MARK: - Calendar Extension
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
} 