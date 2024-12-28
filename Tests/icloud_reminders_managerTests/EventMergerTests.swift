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
        let store = EKEventStore()
        defaultCalendar = EKCalendar(for: .event, eventStore: store)
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
        try eventStore.remove(event1, commit: true)
        try eventStore.remove(event2, commit: true)
        try eventStore.remove(event3, commit: true)
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
        try eventStore.remove(primary, commit: true)
        try eventStore.remove(duplicate, commit: true)
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
        try eventStore.remove(event1, commit: true)
        try eventStore.remove(event2, commit: true)
        try eventStore.remove(event3, commit: true)
        XCTAssertEqual(eventStore.mockEvents.count, 0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestEvent(withTitle title: String, startDate: Date) -> EKEvent {
        let event = eventStore.createMockEvent()
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        event.calendar = defaultCalendar
        return event
    }
} 