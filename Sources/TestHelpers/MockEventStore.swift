import Foundation
import EventKit
import App

public class MockEventStore: EKEventStore {
    private var mockEvents: [EKEvent] = []
    private var mockSources: [EKSource] = []
    private var mockCalendars: [EKCalendar] = []
    
    public override var sources: [EKSource] {
        return mockSources
    }
    
    public override func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        return true
    }
    
    public override func save(_ event: EKEvent, span: EKSpan) throws {
        if !mockEvents.contains(where: { $0 === event }) {
            mockEvents.append(event)
        }
    }
    
    public override func remove(_ event: EKEvent, span: EKSpan) throws {
        mockEvents.removeAll { $0 === event }
    }
    
    public override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
    
    public override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars
    }
    
    public override func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        return NSPredicate { event, _ in
            guard let event = event as? EKEvent else { return false }
            let inTimeRange = event.startDate >= startDate && event.startDate <= endDate
            if let calendars = calendars {
                return inTimeRange && calendars.contains(where: { $0 === event.calendar })
            }
            return inTimeRange
        }
    }
    
    // Helper methods for testing
    public func addMockSource(_ source: EKSource) {
        mockSources.append(source)
    }
    
    public func addMockCalendar(_ calendar: EKCalendar) {
        mockCalendars.append(calendar)
    }
    
    public func createMockSource(title: String, type: EKSourceType) -> EKSource {
        let source = EKSource()
        source.setValue(title, forKey: "title")
        source.setValue(type.rawValue, forKey: "sourceType")
        mockSources.append(source)
        return source
    }
    
    public func createMockCalendar(for entityType: EKEntityType, title: String, source: EKSource) -> EKCalendar {
        let calendar = EKCalendar(for: entityType, eventStore: self)
        calendar.title = title
        calendar.source = source
        mockCalendars.append(calendar)
        return calendar
    }
    
    public func createMockEvent(title: String, startDate: Date, calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: self)
        event.title = title
        event.startDate = startDate
        event.endDate = startDate.addingTimeInterval(3600)
        event.calendar = calendar
        mockEvents.append(event)
        return event
    }
} 