import Foundation
import EventKit

protocol EventStoreProtocol {
    var defaultCalendarForNewEvents: EKCalendar? { get }
    var defaultCalendarForNewReminders: EKCalendar? { get }
    var sources: [EKSource] { get }
    
    func requestAccess(to entityType: EKEntityType) async throws -> Bool
    func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any
    func events(matching predicate: NSPredicate) -> [EKEvent]
    func save(_ object: EKCalendarItem, commit: Bool) throws
    func remove(_ object: EKCalendarItem, commit: Bool) throws
    func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws
    func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws
    func calendar(withIdentifier identifier: String) -> EKCalendar?
    func calendarItem(withIdentifier identifier: String) -> EKCalendarItem?
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