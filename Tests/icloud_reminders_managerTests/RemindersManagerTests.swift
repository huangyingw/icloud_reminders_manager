import XCTest
import EventKit
@testable import icloud_reminders_manager_core

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
        defaultCalendar = EKCalendar(for: .reminder, eventStore: eventStore)
        defaultCalendar.source = mockSource
        defaultCalendar.title = "Test Calendar"
        try eventStore.saveCalendar(defaultCalendar, commit: true)
    }
    
    override func tearDown() async throws {
        eventStore = nil
        remindersManager = nil
        defaultCalendar = nil
        try await super.tearDown()
    }
    
    func testRequestAccess() async throws {
        let granted = try await remindersManager.requestAccess()
        XCTAssertTrue(granted)
        
        eventStore.shouldGrantAccess = false
        let denied = try await remindersManager.requestAccess()
        XCTAssertFalse(denied)
    }
    
    func testFetchIncompleteReminders() async throws {
        // Create test reminders
        let reminder1 = createTestReminder(withTitle: "Test 1", isCompleted: false)
        let reminder2 = createTestReminder(withTitle: "Test 2", isCompleted: false)
        let completedReminder = createTestReminder(withTitle: "Completed", isCompleted: true)
        
        // Set up mock response
        eventStore.mockFetchRemindersResponse = [reminder1, reminder2]
        
        let incompleteReminders = try await remindersManager.fetchIncompleteReminders()
        
        // Should only find incomplete reminders
        XCTAssertEqual(incompleteReminders.count, 2)
        XCTAssertTrue(incompleteReminders.contains { $0.title == "Test 1" })
        XCTAssertTrue(incompleteReminders.contains { $0.title == "Test 2" })
        XCTAssertFalse(incompleteReminders.contains { $0.title == "Completed" })
        
        // Cleanup
        try eventStore.remove(reminder1, commit: true)
        try eventStore.remove(reminder2, commit: true)
        try eventStore.remove(completedReminder, commit: true)
    }
    
    func testMarkAsCompleted() async throws {
        let reminder = createTestReminder(withTitle: "Test", isCompleted: false)
        try await remindersManager.markAsCompleted(reminder)
        
        XCTAssertTrue(reminder.isCompleted)
        
        // Cleanup
        try eventStore.remove(reminder, commit: true)
    }
    
    // MARK: - Helper Methods
    
    private func createTestReminder(withTitle title: String, isCompleted: Bool) -> EKReminder {
        let reminder = eventStore.createMockReminder()
        reminder.title = title
        reminder.isCompleted = isCompleted
        reminder.calendar = defaultCalendar
        try? eventStore.save(reminder, commit: true)
        return reminder
    }
} 