import XCTest
import EventKit
@testable import icloud_reminders_manager

final class EventMergerTests: XCTestCase {
    var eventStore: MockEventStore!
    var eventMerger: EventMerger!
    var defaultCalendar: EKCalendar!
    
    override func setUp() async throws {
        try await super.setUp()
        eventStore = MockEventStore()
        eventStore.shouldGrantAccess = true
        eventMerger = EventMerger()
        
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
        let now = Date()
        
        // Create test events
        let event1 = createTestEvent(withTitle: "Meeting", startDate: now)
        let event2 = createTestEvent(withTitle: "Meeting", startDate: now.addingTimeInterval(60)) // 1 minute later
        let event3 = createTestEvent(withTitle: "Different Meeting", startDate: now)
        
        eventStore.mockEvents = [event1, event2, event3]
        let duplicates = eventMerger.findDuplicateEvents([event1, event2, event3])
        
        // Verify
        XCTAssertEqual(duplicates.count, 1, "Should find one group of duplicates")
        if let firstGroup = duplicates.first {
            XCTAssertEqual(firstGroup.0.title, "Meeting")
            XCTAssertEqual(firstGroup.1.count, 1)
        }
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(event3, span: .thisEvent, commit: true)
        XCTAssertEqual(eventStore.mockEvents.count, 0)
    }
    
    func testMergeEvents() async throws {
        let now = Date()
        
        // Create test events with different properties
        let primary = createTestEvent(withTitle: "Meeting", startDate: now)
        primary.notes = "Primary notes"
        
        let duplicate = createTestEvent(withTitle: "Meeting", startDate: now)
        duplicate.notes = "Duplicate notes"
        duplicate.url = URL(string: "https://example.com")!
        
        eventStore.mockEvents = [primary, duplicate]
        let merged = eventMerger.mergeEvents(primary, with: [duplicate])
        
        // Verify merged properties
        XCTAssertTrue(merged.notes?.contains("Primary notes") ?? false)
        XCTAssertTrue(merged.notes?.contains("Duplicate notes") ?? false)
        XCTAssertNotNil(merged.url)
        
        // Cleanup
        try eventStore.remove(primary, span: .thisEvent, commit: true)
        try eventStore.remove(duplicate, span: .thisEvent, commit: true)
        XCTAssertEqual(eventStore.mockEvents.count, 0)
    }
    
    func testSimilarTitlesWithLevenshteinDistance() async throws {
        let now = Date()
        
        // Create test events with similar titles
        let event1 = createTestEvent(withTitle: "Team Meeting", startDate: now)
        let event2 = createTestEvent(withTitle: "Team Meting", startDate: now) // Typo
        let event3 = createTestEvent(withTitle: "Completely Different", startDate: now)
        
        eventStore.mockEvents = [event1, event2, event3]
        let duplicates = eventMerger.findDuplicateEvents([event1, event2, event3])
        
        // Verify
        XCTAssertEqual(duplicates.count, 1, "Should find one group of duplicates")
        if let firstGroup = duplicates.first {
            XCTAssertTrue(firstGroup.0.title == "Team Meeting" || firstGroup.0.title == "Team Meting")
            XCTAssertEqual(firstGroup.1.count, 1)
        }
        
        // Cleanup
        try eventStore.remove(event1, span: .thisEvent, commit: true)
        try eventStore.remove(event2, span: .thisEvent, commit: true)
        try eventStore.remove(event3, span: .thisEvent, commit: true)
        XCTAssertEqual(eventStore.mockEvents.count, 0)
    }
    
    func testMergeEventsWithDifferentAlarms() async throws {
        let now = Date()
        
        // Create test events with different alarms
        let primary = createTestEvent(withTitle: "Meeting", startDate: now)
        let alarm1 = EKAlarm(relativeOffset: -900) // 15 minutes before
        primary.addAlarm(alarm1)
        
        let duplicate = createTestEvent(withTitle: "Meeting", startDate: now)
        let alarm2 = EKAlarm(relativeOffset: -1800) // 30 minutes before
        duplicate.addAlarm(alarm2)
        
        eventStore.mockEvents = [primary, duplicate]
        let merged = eventMerger.mergeEvents(primary, with: [duplicate])
        
        // Verify merged alarms
        XCTAssertEqual(merged.alarms?.count, 2, "Should have both alarms")
        XCTAssertTrue(merged.alarms?.contains { $0.relativeOffset == -900 } ?? false)
        XCTAssertTrue(merged.alarms?.contains { $0.relativeOffset == -1800 } ?? false)
        
        // Cleanup
        try eventStore.remove(primary, span: .thisEvent, commit: true)
        try eventStore.remove(duplicate, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithDifferentLocations() async throws {
        let now = Date()
        
        // Create test events with different locations
        let primary = createTestEvent(withTitle: "Meeting", startDate: now)
        primary.location = "Room A"
        
        let duplicate = createTestEvent(withTitle: "Meeting", startDate: now)
        duplicate.location = "Room B"
        
        eventStore.mockEvents = [primary, duplicate]
        let merged = eventMerger.mergeEvents(primary, with: [duplicate])
        
        // Verify merged locations
        XCTAssertEqual(merged.location, "Room A", "Should keep primary location")
        XCTAssertTrue(merged.notes?.contains("Room A") ?? false)
        XCTAssertTrue(merged.notes?.contains("Room B") ?? false)
        
        // Cleanup
        try eventStore.remove(primary, span: .thisEvent, commit: true)
        try eventStore.remove(duplicate, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithDifferentURLs() async throws {
        let now = Date()
        
        // Create test events with different URLs
        let primary = createTestEvent(withTitle: "Meeting", startDate: now)
        primary.url = URL(string: "https://example1.com")!
        
        let duplicate = createTestEvent(withTitle: "Meeting", startDate: now)
        duplicate.url = URL(string: "https://example2.com")!
        
        eventStore.mockEvents = [primary, duplicate]
        let merged = eventMerger.mergeEvents(primary, with: [duplicate])
        
        // Verify merged URLs
        XCTAssertEqual(merged.url, URL(string: "https://example1.com")!)
        XCTAssertTrue(merged.notes?.contains("https://example1.com") ?? false)
        XCTAssertTrue(merged.notes?.contains("https://example2.com") ?? false)
        
        // Cleanup
        try eventStore.remove(primary, span: .thisEvent, commit: true)
        try eventStore.remove(duplicate, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithOverlappingTimes() async throws {
        let now = Date()
        
        // Create test events with overlapping times
        let primary = createTestEvent(withTitle: "Meeting", startDate: now)
        primary.endDate = now.addingTimeInterval(3600) // 1 hour duration
        
        let duplicate = createTestEvent(withTitle: "Meeting", startDate: now.addingTimeInterval(1800)) // 30 minutes later
        duplicate.endDate = now.addingTimeInterval(5400) // 1.5 hours duration
        
        eventStore.mockEvents = [primary, duplicate]
        let merged = eventMerger.mergeEvents(primary, with: [duplicate])
        
        // Verify merged times using time intervals (allowing for small differences)
        let startDiff = abs(merged.startDate.timeIntervalSince(now))
        let endDiff = abs(merged.endDate.timeIntervalSince(now.addingTimeInterval(5400)))
        
        XCTAssertLessThan(startDiff, 1.0, "Start dates should be within 1 second")
        XCTAssertLessThan(endDiff, 1.0, "End dates should be within 1 second")
        
        // Cleanup
        try eventStore.remove(primary, span: .thisEvent, commit: true)
        try eventStore.remove(duplicate, span: .thisEvent, commit: true)
    }
    
    func testMergeEventsWithRecurrence() async throws {
        let now = Date()
        
        // Create test events with recurrence rules
        let primary = createTestEvent(withTitle: "Weekly Meeting", startDate: now)
        let recurrenceRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: nil
        )
        primary.recurrenceRules = [recurrenceRule]
        try eventStore.save(primary, span: .thisEvent, commit: true)
        
        let duplicate = createTestEvent(withTitle: "Weekly Meeting", startDate: now)
        let duplicateRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 2,
            end: EKRecurrenceEnd(occurrenceCount: 10)
        )
        duplicate.recurrenceRules = [duplicateRule]
        try eventStore.save(duplicate, span: .thisEvent, commit: true)
        
        let merged = eventMerger.mergeEvents(primary, with: [duplicate])
        try eventStore.save(merged, span: .thisEvent, commit: true)
        
        // Verify merged recurrence rules
        XCTAssertNotNil(merged.recurrenceRules, "Merged event should have recurrence rules")
        XCTAssertEqual(merged.recurrenceRules?.count, 1, "Should have one recurrence rule")
        XCTAssertEqual(merged.recurrenceRules?.first?.frequency, .weekly, "Should keep weekly frequency")
        XCTAssertEqual(merged.recurrenceRules?.first?.interval, 1, "Should keep the shorter interval")
        XCTAssertNil(merged.recurrenceRules?.first?.recurrenceEnd, "Should keep the rule without end")
        
        // Verify notes contain information about the original recurrence rules
        XCTAssertTrue(merged.notes?.contains("Weekly") ?? false)
        XCTAssertTrue(merged.notes?.contains("interval: 1") ?? false)
        XCTAssertTrue(merged.notes?.contains("interval: 2") ?? false)
        XCTAssertTrue(merged.notes?.contains("occurrences: 10") ?? false)
        
        // Cleanup
        try eventStore.remove(primary, span: .thisEvent, commit: true)
        try eventStore.remove(duplicate, span: .thisEvent, commit: true)
    }
    
    // MARK: - Helper Methods
    
    private func createTestEvent(withTitle title: String, startDate: Date) -> EKEvent {
        let event = eventStore.createMockEvent()
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        event.calendar = defaultCalendar
        try? eventStore.save(event, span: .thisEvent, commit: true)
        return event
    }
} 