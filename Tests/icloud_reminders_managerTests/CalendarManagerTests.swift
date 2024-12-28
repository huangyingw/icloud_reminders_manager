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
        let store = EKEventStore()
        defaultCalendar = EKCalendar(for: .event, eventStore: store)
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
        let hasAccess = try await calendarManager.requestAccess()
        XCTAssertTrue(hasAccess, "Should have access to calendar")
        
        // Test denied access
        eventStore.shouldGrantAccess = false
        let noAccess = try await calendarManager.requestAccess()
        XCTAssertFalse(noAccess, "Should not have access to calendar")
    }
    
    func testCreateEventFromReminder() async throws {
        // Create test data
        let dueDate = Date()
        let reminder = createTestReminder(withTitle: "Test Event", dueDate: dueDate)
        let reminderModel = Reminder(from: reminder)
        
        // Create event
        let event = try calendarManager.createEvent(from: reminderModel, in: defaultCalendar)
        
        // Verify
        XCTAssertEqual(event.title, reminderModel.title)
        XCTAssertEqual(event.startDate, reminderModel.dueDate)
        XCTAssertEqual(eventStore.mockEvents.count, 1)
        
        // Cleanup
        try eventStore.remove(event, commit: true)
        XCTAssertEqual(eventStore.mockEvents.count, 0)
    }
    
    func testMoveEventToCurrentWeek() async throws {
        // Create a test event from last week
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date())!
        let event = createTestEvent(withTitle: "Past Event", startDate: lastWeek)
        
        // Move event
        try calendarManager.moveEventToCurrentWeek(event)
        
        // Verify the event was moved to current week
        let currentWeekStart = calendar.startOfWeek(for: Date())
        let currentWeekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        
        XCTAssertTrue(event.startDate >= currentWeekStart)
        XCTAssertTrue(event.startDate < currentWeekEnd)
        
        // Cleanup
        try eventStore.remove(event, commit: true)
    }
    
    // MARK: - Helper Methods
    
    private func createTestReminder(withTitle title: String, dueDate: Date) -> EKReminder {
        let reminder = eventStore.createMockReminder()
        reminder.title = title
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        reminder.calendar = eventStore.defaultCalendarForNewReminders
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