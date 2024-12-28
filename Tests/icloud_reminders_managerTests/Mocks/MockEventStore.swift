import Foundation
import EventKit
@testable import icloud_reminders_manager

class MockEventStore: EventStoreProtocol {
    var shouldGrantAccess = true
    var mockReminders: [EKReminder] = []
    var mockEvents: [EKEvent] = []
    var mockCalendars: [EKCalendar] = []
    var mockSources: [EKSource] = []
    private var nextEventId = 1
    private var nextReminderId = 1
    private var eventIdentifiers: [EKEvent: String] = [:]
    private var reminderIdentifiers: [EKReminder: String] = [:]
    
    func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        return shouldGrantAccess
    }
    
    func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        completion(mockReminders)
        return NSObject()
    }
    
    func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
    
    var sources: [EKSource] {
        return mockSources
    }
    
    var defaultCalendarForNewEvents: EKCalendar? {
        return mockCalendars.first(where: { $0.allowedEntityTypes.contains(.event) })
    }
    
    var defaultCalendarForNewReminders: EKCalendar? {
        return mockCalendars.first(where: { $0.allowedEntityTypes.contains(.reminder) })
    }
    
    func save(_ object: EKCalendarItem, commit: Bool) throws {
        if let reminder = object as? EKReminder {
            if !mockReminders.contains(where: { $0 === reminder }) {
                reminderIdentifiers[reminder] = "reminder-\(nextReminderId)"
                nextReminderId += 1
                mockReminders.append(reminder)
            }
        } else if let event = object as? EKEvent {
            if !mockEvents.contains(where: { $0 === event }) {
                eventIdentifiers[event] = "event-\(nextEventId)"
                nextEventId += 1
                mockEvents.append(event)
            }
        }
    }
    
    func remove(_ object: EKCalendarItem, commit: Bool) throws {
        if let reminder = object as? EKReminder {
            mockReminders.removeAll { $0 === reminder }
            reminderIdentifiers.removeValue(forKey: reminder)
        } else if let event = object as? EKEvent {
            mockEvents.removeAll { $0 === event }
            eventIdentifiers.removeValue(forKey: event)
        }
    }
    
    func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        if !mockCalendars.contains(where: { $0 === calendar }) {
            mockCalendars.append(calendar)
        }
    }
    
    func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        mockCalendars.removeAll { $0 === calendar }
    }
    
    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        return mockCalendars.first(where: { $0.calendarIdentifier == identifier })
    }
    
    func calendarItem(withIdentifier identifier: String) -> EKCalendarItem? {
        if let event = mockEvents.first(where: { eventIdentifiers[$0] == identifier }) {
            return event
        }
        return mockReminders.first(where: { reminderIdentifiers[$0] == identifier })
    }
    
    func createMockEvent() -> EKEvent {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.calendar = defaultCalendarForNewEvents
        eventIdentifiers[event] = "event-\(nextEventId)"
        nextEventId += 1
        try? save(event, commit: true)
        return event
    }
    
    func createMockReminder() -> EKReminder {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = defaultCalendarForNewReminders
        reminderIdentifiers[reminder] = "reminder-\(nextReminderId)"
        nextReminderId += 1
        try? save(reminder, commit: true)
        return reminder
    }
    
    func getEventIdentifier(_ event: EKEvent) -> String? {
        return eventIdentifiers[event]
    }
    
    func getCalendarItemIdentifier(_ item: EKCalendarItem) -> String? {
        if let event = item as? EKEvent {
            return eventIdentifiers[event]
        } else if let reminder = item as? EKReminder {
            return reminderIdentifiers[reminder]
        }
        return nil
    }
} 