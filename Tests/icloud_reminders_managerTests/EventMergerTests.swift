import XCTest
import EventKit
@testable import icloud_reminders_manager_core

final class EventMergerTests: XCTestCase {
    var eventStore: MockEventStore!
    var eventMerger: EventMerger!
    var defaultCalendar: EKCalendar!
    
    override func setUp() async throws {
        try await super.setUp()
        eventStore = MockEventStore()
        eventStore.shouldGrantAccess = true
        eventMerger = EventMerger(eventStore: eventStore)
        
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
        eventMerger = nil
        defaultCalendar = nil
        try await super.tearDown()
    }
    
    func testFindDuplicateEvents() async throws {
        // Create test events
        let event1 = createTestEvent(withTitle: "Team Meeting")
        let event2 = createTestEvent(withTitle: "Team Meeting")
        let event3 = createTestEvent(withTitle: "Different Meeting")
        
        let duplicates = eventMerger.findDuplicateEvents([event1, event2, event3])
        
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertEqual(duplicates.first?.count, 2)
        XCTAssertTrue(duplicates.first?.contains(event1) ?? false)
        XCTAssertTrue(duplicates.first?.contains(event2) ?? false)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(event3, span: .thisEvent, commit: true)
    }
    
    func testMergeEvents() async throws {
        // Create test events
        let event1 = createTestEvent(withTitle: "Team Meeting")
        event1.notes = "Agenda 1"
        
        let event2 = createTestEvent(withTitle: "Team Meeting")
        event2.notes = "Agenda 2"
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2])
        
        XCTAssertEqual(mergedEvent.title, "Team Meeting")
        XCTAssertEqual(mergedEvent.notes, "Agenda 1\n\nAgenda 2")
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithDifferentNotes() async throws {
        let event1 = createTestEvent(withTitle: "Meeting")
        event1.notes = "Note 1"
        
        let event2 = createTestEvent(withTitle: "Meeting")
        event2.notes = "Note 2"
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2])
        
        XCTAssertEqual(mergedEvent.notes, "Note 1\n\nNote 2")
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithDifferentURLs() async throws {
        let event1 = createTestEvent(withTitle: "Meeting")
        event1.url = URL(string: "https://example1.com")
        
        let event2 = createTestEvent(withTitle: "Meeting")
        event2.url = URL(string: "https://example2.com")
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2])
        
        XCTAssertEqual(mergedEvent.url, event1.url)
        XCTAssertTrue(mergedEvent.notes?.contains("https://example2.com") ?? false)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithConflictingURLs() async throws {
        let event1 = createTestEvent(withTitle: "Meeting")
        event1.url = URL(string: "https://example1.com")
        
        let event2 = createTestEvent(withTitle: "Meeting")
        event2.url = URL(string: "https://example2.com")
        
        let config = MergeConfiguration(preferredURL: event2.url)
        let mergedEvent = try eventMerger.mergeEvents([event1, event2], config: config)
        
        XCTAssertEqual(mergedEvent.url, event2.url)
        XCTAssertTrue(mergedEvent.notes?.contains("https://example1.com") ?? false)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithDifferentLocations() async throws {
        let event1 = createTestEvent(withTitle: "Meeting")
        event1.location = "Room 1"
        
        let event2 = createTestEvent(withTitle: "Meeting")
        event2.location = "Room 2"
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2])
        
        XCTAssertEqual(mergedEvent.location, event1.location)
        XCTAssertTrue(mergedEvent.notes?.contains("Room 2") ?? false)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithDifferentAlarms() async throws {
        let event1 = createTestEvent(withTitle: "Meeting")
        event1.addAlarm(EKAlarm(relativeOffset: -3600)) // 1 hour before
        
        let event2 = createTestEvent(withTitle: "Meeting")
        event2.addAlarm(EKAlarm(relativeOffset: -1800)) // 30 minutes before
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2])
        
        XCTAssertEqual(mergedEvent.alarms?.count, 2)
        XCTAssertTrue(mergedEvent.alarms?.contains { $0.relativeOffset == -3600 } ?? false)
        XCTAssertTrue(mergedEvent.alarms?.contains { $0.relativeOffset == -1800 } ?? false)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithDifferentReminders() async throws {
        let event1 = createTestEvent(withTitle: "Meeting")
        event1.addAlarm(EKAlarm(relativeOffset: -3600))
        
        let event2 = createTestEvent(withTitle: "Meeting")
        event2.addAlarm(EKAlarm(relativeOffset: -1800))
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2])
        
        XCTAssertEqual(mergedEvent.alarms?.count, 2)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithRecurrence() async throws {
        let event1 = createTestEvent(withTitle: "Weekly Meeting")
        event1.addRecurrenceRule(EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: nil
        ))
        
        let event2 = createTestEvent(withTitle: "Weekly Meeting")
        event2.addRecurrenceRule(EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: nil
        ))
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2])
        
        XCTAssertNotNil(mergedEvent.recurrenceRules)
        XCTAssertEqual(mergedEvent.recurrenceRules?.count, 1)
        XCTAssertEqual(mergedEvent.recurrenceRules?.first?.frequency, .weekly)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithSimilarTimes() async throws {
        let now = Date()
        
        let event1 = createTestEvent(withTitle: "Meeting")
        event1.startDate = now
        event1.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        
        let event2 = createTestEvent(withTitle: "Meeting")
        event2.startDate = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
        event2.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event2.startDate)!
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2])
        
        XCTAssertEqual(mergedEvent.startDate, event1.startDate)
        XCTAssertEqual(mergedEvent.endDate, event2.endDate)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testCustomMergeConfiguration() async throws {
        let event1 = createTestEvent(withTitle: "Meeting")
        event1.location = "Room 1"
        event1.url = URL(string: "https://example1.com")
        
        let event2 = createTestEvent(withTitle: "Meeting")
        event2.location = "Room 2"
        event2.url = URL(string: "https://example2.com")
        
        let config = MergeConfiguration(
            preferredLocation: event2.location,
            preferredURL: event2.url
        )
        
        let mergedEvent = try eventMerger.mergeEvents([event1, event2], config: config)
        
        XCTAssertEqual(mergedEvent.location, event2.location)
        XCTAssertEqual(mergedEvent.url, event2.url)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(mergedEvent, span: .thisEvent, commit: true)
    }
    
    func testSimilarTitlesWithLevenshteinDistance() async throws {
        let event1 = createTestEvent(withTitle: "Team Meeting")
        let event2 = createTestEvent(withTitle: "Team Meting") // Typo
        let event3 = createTestEvent(withTitle: "Different Meeting")
        
        let duplicates = eventMerger.findDuplicateEvents([event1, event2, event3])
        
        XCTAssertEqual(duplicates.count, 1)
        XCTAssertEqual(duplicates.first?.count, 2)
        XCTAssertTrue(duplicates.first?.contains(event1) ?? false)
        XCTAssertTrue(duplicates.first?.contains(event2) ?? false)
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(event3, span: .thisEvent, commit: true)
    }
    
    // MARK: - Helper Methods
    
    private func createTestEvent(withTitle title: String) -> EKEvent {
        let event = eventStore.createMockEvent()
        event.title = title
        event.startDate = Date()
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.calendar = defaultCalendar
        try? eventStore.save(event, span: .thisEvent, commit: true)
        return event
    }
} 