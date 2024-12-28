import XCTest
import EventKit
@testable import icloud_reminders_manager

final class RemindersManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var remindersManager: RemindersManager!
    var defaultCalendar: EKCalendar!
    
    override func setUp() async throws {
        try await super.setUp()
        eventStore = MockEventStore()
        eventStore.shouldGrantAccess = true
        remindersManager = RemindersManager(eventStore: eventStore)
        
        // Setup mock source
        let mockSource = MockSource(sourceType: .local)
        eventStore.mockSources = [mockSource]
        
        // Setup calendar
        let store = EKEventStore()
        defaultCalendar = EKCalendar(for: .reminder, eventStore: store)
        defaultCalendar.source = mockSource
        defaultCalendar.title = "Test Reminders"
        try eventStore.saveCalendar(defaultCalendar, commit: true)
    }
    
    override func tearDown() async throws {
        eventStore = nil
        remindersManager = nil
        defaultCalendar = nil
        try await super.tearDown()
    }
    
    func testRequestAccess() async throws {
        let hasAccess = try await remindersManager.requestAccess()
        XCTAssertTrue(hasAccess, "Should have access to reminders")
        
        // Test denied access
        eventStore.shouldGrantAccess = false
        let noAccess = try await remindersManager.requestAccess()
        XCTAssertFalse(noAccess, "Should not have access to reminders")
    }
    
    func testFetchIncompleteReminders() async throws {
        // Create a test reminder
        let reminder = eventStore.createMockReminder()
        reminder.title = "Test Reminder"
        reminder.calendar = defaultCalendar
        
        // Fetch reminders
        let reminders = try await remindersManager.fetchIncompleteReminders()
        
        // Verify
        XCTAssertFalse(reminders.isEmpty, "Should have at least one reminder")
        XCTAssertTrue(reminders.contains { $0.title == "Test Reminder" })
        XCTAssertEqual(eventStore.mockReminders.count, 1)
        
        // Cleanup
        try eventStore.remove(reminder, commit: true)
        XCTAssertEqual(eventStore.mockReminders.count, 0)
    }
} 