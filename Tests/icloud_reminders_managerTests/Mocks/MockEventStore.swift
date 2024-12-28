import Foundation
import EventKit

class MockEventStore: EKEventStore {
    var shouldGrantAccess = true
    var mockEvents: [EKEvent] = []
    var mockReminders: [EKReminder] = []
    var mockSources: [EKSource] = []
    var mockCalendars: [EKCalendar] = []
    
    override func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        return shouldGrantAccess
    }
    
    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars
    }
    
    override var sources: [EKSource] {
        return mockSources
    }
    
    override func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        if !mockEvents.contains(where: { $0 === event }) {
            mockEvents.append(event)
        }
        
        // Update existing event if it exists
        if let index = mockEvents.firstIndex(where: { $0 === event }) {
            mockEvents[index] = event
        }
    }
    
    override func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        mockEvents.removeAll { $0 === event }
    }
    
    override func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        if !mockCalendars.contains(where: { $0 === calendar }) {
            mockCalendars.append(calendar)
        }
    }
    
    override func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        mockCalendars.removeAll { $0 === calendar }
    }
    
    func createMockEvent() -> EKEvent {
        let event = EKEvent(eventStore: self)
        event.startDate = Date()
        event.endDate = Date()
        return event
    }
    
    func createMockReminder() -> EKReminder {
        let reminder = EKReminder(eventStore: self)
        mockReminders.append(reminder)
        return reminder
    }
    
    override func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        completion(mockReminders)
        return NSObject()
    }
    
    override func save(_ reminder: EKReminder, commit: Bool) throws {
        if !mockReminders.contains(where: { $0 === reminder }) {
            mockReminders.append(reminder)
        }
    }
    
    override func remove(_ reminder: EKReminder, commit: Bool) throws {
        mockReminders.removeAll { $0 === reminder }
    }
    
    override func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        return NSPredicate(value: true)
    }
    
    override func predicateForIncompleteReminders(withDueDateStarting startDate: Date?, ending endDate: Date?, calendars: [EKCalendar]?) -> NSPredicate {
        return NSPredicate(value: true)
    }
    
    override func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        return NSPredicate(value: true)
    }
    
    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
} 