import Foundation
import EventKit

class MockEventStore: EKEventStore {
    var shouldGrantAccess = true
    var mockSources: [EKSource] = []
    var mockCalendars: [EKCalendar] = []
    var mockReminders: [EKReminder] = []
    var mockEvents: [EKEvent] = []
    var mockFetchRemindersResponse: [EKReminder] = []
    
    override func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        return shouldGrantAccess
    }
    
    override var sources: [EKSource] {
        return mockSources
    }
    
    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars
    }
    
    override func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        mockCalendars.append(calendar)
    }
    
    override func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        if let index = mockCalendars.firstIndex(of: calendar) {
            mockCalendars.remove(at: index)
        }
    }
    
    override func save(_ reminder: EKReminder, commit: Bool) throws {
        if !mockReminders.contains(reminder) {
            mockReminders.append(reminder)
        }
    }
    
    override func remove(_ reminder: EKReminder, commit: Bool) throws {
        if let index = mockReminders.firstIndex(of: reminder) {
            mockReminders.remove(at: index)
        }
    }
    
    override func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        if !mockEvents.contains(event) {
            mockEvents.append(event)
        }
    }
    
    override func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        if let index = mockEvents.firstIndex(of: event) {
            mockEvents.remove(at: index)
        }
    }
    
    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
    
    override func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        completion(mockFetchRemindersResponse)
        return NSObject()
    }
    
    func createMockReminder() -> EKReminder {
        return EKReminder(eventStore: self)
    }
    
    func createMockEvent() -> EKEvent {
        return EKEvent(eventStore: self)
    }
    
    func createMockCalendar(for entityType: EKEntityType) -> EKCalendar {
        return EKCalendar(for: entityType, eventStore: self)
    }
} 