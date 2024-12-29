import Foundation
import EventKit

enum MockError: Error {
    case testError
}

class MockEventStore: EKEventStore {
    var shouldGrantAccess = true
    var shouldThrowError = false
    var mockEvents: [EKEvent] = []
    var mockCalendars: [EKCalendar] = []
    var mockSources: [EKSource] = []
    var mockReminders: [EKReminder] = []
    var mockFetchRemindersResponse: [EKReminder] = []
    
    override func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        return shouldGrantAccess
    }
    
    override func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        if shouldThrowError {
            throw MockError.testError
        }
        if !mockEvents.contains(where: { $0 === event }) {
            mockEvents.append(event)
        }
    }
    
    override func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        if shouldThrowError {
            throw MockError.testError
        }
        mockEvents.removeAll(where: { $0 === event })
    }
    
    override func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        if shouldThrowError {
            throw MockError.testError
        }
        if !mockCalendars.contains(where: { $0 === calendar }) {
            mockCalendars.append(calendar)
        }
    }
    
    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
    
    override var sources: [EKSource] {
        return mockSources
    }
    
    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars
    }
    
    override func save(_ reminder: EKReminder, commit: Bool) throws {
        if shouldThrowError {
            throw MockError.testError
        }
        if !mockReminders.contains(where: { $0 === reminder }) {
            mockReminders.append(reminder)
        }
    }
    
    override func remove(_ reminder: EKReminder, commit: Bool) throws {
        if shouldThrowError {
            throw MockError.testError
        }
        mockReminders.removeAll(where: { $0 === reminder })
    }
    
    override func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        completion(mockFetchRemindersResponse)
        return NSObject()
    }
    
    func createMockEvent() -> EKEvent {
        return EKEvent(eventStore: self)
    }
    
    func createMockReminder() -> EKReminder {
        return EKReminder(eventStore: self)
    }
} 