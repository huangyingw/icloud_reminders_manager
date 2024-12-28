import Foundation
import EventKit

protocol EventStoreProtocol {
    func requestAccess(to entityType: EKEntityType) async throws -> Bool
    func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any
    func events(matching predicate: NSPredicate) -> [EKEvent]
    var sources: [EKSource] { get }
    var defaultCalendarForNewEvents: EKCalendar? { get }
    var defaultCalendarForNewReminders: EKCalendar? { get }
    func save(_ object: EKCalendarItem, commit: Bool) throws
    func remove(_ object: EKCalendarItem, commit: Bool) throws
    func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws
    func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws
    func calendar(withIdentifier identifier: String) -> EKCalendar?
    func calendarItem(withIdentifier identifier: String) -> EKCalendarItem?
    func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws
    func save(_ reminder: EKReminder, commit: Bool) throws
    func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws
    func remove(_ reminder: EKReminder, commit: Bool) throws
    func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate
    func predicateForIncompleteReminders(withDueDateStarting startDate: Date?, ending endDate: Date?, calendars: [EKCalendar]?) -> NSPredicate
    func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate
}

extension EKEventStore: EventStoreProtocol {
    var defaultCalendarForNewReminders: EKCalendar? {
        return defaultCalendarForNewEvents
    }
    
    func save(_ object: EKCalendarItem, commit: Bool) throws {
        if let event = object as? EKEvent {
            try save(event, span: .thisEvent, commit: commit)
        } else if let reminder = object as? EKReminder {
            try save(reminder, commit: commit)
        }
    }
    
    func remove(_ object: EKCalendarItem, commit: Bool) throws {
        if let event = object as? EKEvent {
            try remove(event, span: .thisEvent, commit: commit)
        } else if let reminder = object as? EKReminder {
            try remove(reminder, commit: commit)
        }
    }
} 