import XCTest
import EventKit
@testable import icloud_reminders_manager_core

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
        // Create a test reminder
        let reminder = eventStore.createMockReminder()
        reminder.title = "Test Reminder"
        reminder.notes = "Test Notes"
        reminder.dueDateComponents = DateComponents(year: 2024, month: 1, day: 1, hour: 10, minute: 0)
        reminder.calendar = defaultCalendar
        try eventStore.save(reminder, commit: true)
        
        // Create event from reminder
        let event = try await calendarManager.createEventFromReminder(reminder)
        
        // Verify event properties
        XCTAssertEqual(event.title, reminder.title)
        XCTAssertEqual(event.notes, reminder.notes)
        XCTAssertEqual(event.startDate.timeIntervalSinceReferenceDate,
                      reminder.dueDateComponents?.date?.timeIntervalSinceReferenceDate ?? 0,
                      accuracy: 1)
        XCTAssertEqual(event.endDate.timeIntervalSince(event.startDate), 3600, accuracy: 1)
        XCTAssertEqual(event.calendar, defaultCalendar)
        
        // Cleanup
        try eventStore.remove(reminder, commit: true)
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func testMoveEventToCurrentWeek() async throws {
        // Create a test event from last week
        let event = eventStore.createMockEvent()
        event.title = "Last Week Meeting"
        event.startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.calendar = defaultCalendar
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        // Move event to current week
        try await calendarManager.moveEventToCurrentWeek(event)
        
        // Verify event was moved
        let currentWeekStart = Calendar.current.startOfWeek(for: Date())
        XCTAssertGreaterThanOrEqual(event.startDate, currentWeekStart)
        XCTAssertLessThan(event.startDate, Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!)
        
        // Cleanup
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func testMoveExpiredEventsToCurrentWeek() async throws {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.startOfWeek(for: now)
        
        // Create test events
        let lastWeekEvent = eventStore.createMockEvent()
        lastWeekEvent.title = "Last Week Meeting"
        lastWeekEvent.startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
        lastWeekEvent.endDate = calendar.date(byAdding: .hour, value: 1, to: lastWeekEvent.startDate)!
        lastWeekEvent.calendar = defaultCalendar
        try eventStore.save(lastWeekEvent, span: .thisEvent, commit: true)
        
        let lastMonthEvent = eventStore.createMockEvent()
        lastMonthEvent.title = "Last Month Meeting"
        lastMonthEvent.startDate = calendar.date(byAdding: .month, value: -1, to: now)!
        lastMonthEvent.endDate = calendar.date(byAdding: .hour, value: 1, to: lastMonthEvent.startDate)!
        lastMonthEvent.calendar = defaultCalendar
        try eventStore.save(lastMonthEvent, span: .thisEvent, commit: true)
        
        let futureEvent = eventStore.createMockEvent()
        futureEvent.title = "Future Meeting"
        futureEvent.startDate = calendar.date(byAdding: .weekOfYear, value: 1, to: now)!
        futureEvent.endDate = calendar.date(byAdding: .hour, value: 1, to: futureEvent.startDate)!
        futureEvent.calendar = defaultCalendar
        try eventStore.save(futureEvent, span: .thisEvent, commit: true)
        
        // Move expired events to current week
        try await calendarManager.moveExpiredEventsToCurrentWeek()
        
        // Verify events were moved correctly
        let currentWeekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!
        
        // Verify last week event was moved to current week
        XCTAssertGreaterThanOrEqual(lastWeekEvent.startDate, currentWeekStart)
        XCTAssertLessThan(lastWeekEvent.startDate, currentWeekEnd)
        
        // Verify last month event was moved to current week
        XCTAssertGreaterThanOrEqual(lastMonthEvent.startDate, currentWeekStart)
        XCTAssertLessThan(lastMonthEvent.startDate, currentWeekEnd)
        
        // Verify future event was not moved
        XCTAssertGreaterThanOrEqual(futureEvent.startDate, currentWeekEnd)
        
        // Cleanup
        try eventStore.remove(lastWeekEvent, span: .thisEvent, commit: true)
        try eventStore.remove(lastMonthEvent, span: .thisEvent, commit: true)
        try eventStore.remove(futureEvent, span: .thisEvent, commit: true)
    }
    
    func testDeleteExpiredRecurringEvents() async throws {
        // Create test events
        let expiredWeeklyEvent = eventStore.createMockEvent()
        expiredWeeklyEvent.title = "Expired Weekly"
        expiredWeeklyEvent.startDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        expiredWeeklyEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: expiredWeeklyEvent.startDate)!
        expiredWeeklyEvent.calendar = defaultCalendar
        expiredWeeklyEvent.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: .init(end: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
        )]
        try eventStore.save(expiredWeeklyEvent, span: .thisEvent, commit: true)
        
        let activeWeeklyEvent = eventStore.createMockEvent()
        activeWeeklyEvent.title = "Active Weekly"
        activeWeeklyEvent.startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        activeWeeklyEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: activeWeeklyEvent.startDate)!
        activeWeeklyEvent.calendar = defaultCalendar
        activeWeeklyEvent.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: .init(end: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
        )]
        try eventStore.save(activeWeeklyEvent, span: .thisEvent, commit: true)
        
        // Delete expired recurring events
        try await calendarManager.deleteExpiredRecurringEvents()
        
        // Verify only expired recurring event was deleted
        XCTAssertEqual(eventStore.mockEvents.count, 1)
        XCTAssertEqual(eventStore.mockEvents.first?.title, "Active Weekly")
        XCTAssertFalse(eventStore.mockEvents.contains(expiredWeeklyEvent))
        XCTAssertTrue(eventStore.mockEvents.contains(activeWeeklyEvent))
        
        // Cleanup
        try eventStore.remove(activeWeeklyEvent, span: .thisEvent, commit: true)
    }
    
    func testMoveEventToCurrentWeekWithAllDayEvent() async throws {
        // Create an all-day event from last week
        let event = eventStore.createMockEvent()
        event.title = "Last Week All Day Event"
        event.startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
        event.endDate = Calendar.current.date(byAdding: .day, value: 1, to: event.startDate)!
        event.isAllDay = true
        event.calendar = defaultCalendar
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        // Move event to current week
        try await calendarManager.moveEventToCurrentWeek(event)
        
        // Verify event was moved and remains all-day
        let currentWeekStart = Calendar.current.startOfWeek(for: Date())
        XCTAssertGreaterThanOrEqual(event.startDate, currentWeekStart)
        XCTAssertLessThan(event.startDate, Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!)
        XCTAssertTrue(event.isAllDay)
        XCTAssertEqual(Calendar.current.dateComponents([.hour, .minute], from: event.startDate).hour, 0)
        XCTAssertEqual(Calendar.current.dateComponents([.hour, .minute], from: event.startDate).minute, 0)
        
        // Cleanup
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func testMoveEventToCurrentWeekWithWeekBoundary() async throws {
        let calendar = Calendar.current
        
        // Create an event on Sunday of last week
        let event = eventStore.createMockEvent()
        event.title = "Last Week Sunday Event"
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 1 // Sunday
        components.hour = 15
        components.minute = 30
        let lastWeekSunday = calendar.date(byAdding: .weekOfYear, value: -1, to: calendar.date(from: components)!)!
        
        event.startDate = lastWeekSunday
        event.endDate = calendar.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.calendar = defaultCalendar
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        // Move event to current week
        try await calendarManager.moveEventToCurrentWeek(event)
        
        // Verify event was moved correctly
        let currentWeekStart = calendar.startOfWeek(for: Date())
        XCTAssertGreaterThanOrEqual(event.startDate, currentWeekStart)
        XCTAssertEqual(calendar.component(.weekday, from: event.startDate), 1) // Still on Sunday
        XCTAssertEqual(calendar.component(.hour, from: event.startDate), 15)
        XCTAssertEqual(calendar.component(.minute, from: event.startDate), 30)
        
        // Cleanup
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func testMoveEventToCurrentWeekWithMultiDayEvent() async throws {
        let calendar = Calendar.current
        
        // Create a multi-day event from last week
        let event = eventStore.createMockEvent()
        event.title = "Last Week Multi-day Event"
        event.startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        event.endDate = calendar.date(byAdding: .day, value: 3, to: event.startDate)!
        event.calendar = defaultCalendar
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        // Store original duration
        let originalDuration = event.endDate.timeIntervalSince(event.startDate)
        
        // Move event to current week
        try await calendarManager.moveEventToCurrentWeek(event)
        
        // Verify event was moved and maintains duration
        let currentWeekStart = calendar.startOfWeek(for: Date())
        XCTAssertGreaterThanOrEqual(event.startDate, currentWeekStart)
        XCTAssertLessThan(event.startDate, calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!)
        XCTAssertEqual(event.endDate.timeIntervalSince(event.startDate), originalDuration)
        
        // Cleanup
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func testMoveEventToCurrentWeekWithTimeZone() async throws {
        let calendar = Calendar.current
        
        // Create an event from last week in a different time zone
        let event = eventStore.createMockEvent()
        event.title = "Last Week Event in Different Time Zone"
        event.startDate = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        event.endDate = calendar.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.timeZone = TimeZone(identifier: "America/New_York")
        event.calendar = defaultCalendar
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        // Store original time zone and local time components
        let originalTimeZone = event.timeZone
        let originalHour = calendar.component(.hour, from: event.startDate)
        let originalMinute = calendar.component(.minute, from: event.startDate)
        
        // Move event to current week
        try await calendarManager.moveEventToCurrentWeek(event)
        
        // Verify event was moved and maintains time zone and local time
        let currentWeekStart = calendar.startOfWeek(for: Date())
        XCTAssertGreaterThanOrEqual(event.startDate, currentWeekStart)
        XCTAssertLessThan(event.startDate, calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart)!)
        XCTAssertEqual(event.timeZone, originalTimeZone)
        XCTAssertEqual(calendar.component(.hour, from: event.startDate), originalHour)
        XCTAssertEqual(calendar.component(.minute, from: event.startDate), originalMinute)
        
        // Cleanup
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func testMoveExpiredEventsToCurrentWeekWithErrors() async throws {
        // Configure mock store to throw error
        eventStore.shouldThrowError = true
        
        // Create a test event
        let event = eventStore.createMockEvent()
        event.title = "Test Event"
        event.startDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())!
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.calendar = defaultCalendar
        
        // Save event without error
        eventStore.shouldThrowError = false
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        // Set error flag for move operation
        eventStore.shouldThrowError = true
        
        // Attempt to move expired events and expect error
        do {
            try await calendarManager.moveExpiredEventsToCurrentWeek()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is MockError)
        }
        
        // Reset mock store and cleanup
        eventStore.shouldThrowError = false
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func testDeleteExpiredRecurringEventsWithMultipleRules() async throws {
        let now = Date()
        let calendar = Calendar.current
        
        // Create a test event with multiple recurrence rules
        let event = eventStore.createMockEvent()
        event.title = "Multi-rule Recurring Event"
        event.startDate = calendar.date(byAdding: .month, value: -2, to: now)!
        event.endDate = calendar.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.calendar = defaultCalendar
        
        // Add multiple recurrence rules, both expired
        event.recurrenceRules = [
            EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: .init(end: calendar.date(byAdding: .month, value: -1, to: now)!)
            ),
            EKRecurrenceRule(
                recurrenceWith: .monthly,
                interval: 1,
                end: .init(end: calendar.date(byAdding: .month, value: -1, to: now)!)
            )
        ]
        
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        // Delete expired recurring events
        try await calendarManager.deleteExpiredRecurringEvents()
        
        // Verify event was deleted because all rules are expired
        XCTAssertFalse(eventStore.mockEvents.contains(where: { $0 === event }))
        
        // Cleanup
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
}

// MARK: - Calendar Extension
extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
} 