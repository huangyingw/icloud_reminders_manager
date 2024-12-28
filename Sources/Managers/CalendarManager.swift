import Foundation
import EventKit

class CalendarManager {
    private let eventStore: EventStoreProtocol
    
    init(eventStore: EventStoreProtocol = EKEventStore()) {
        self.eventStore = eventStore
    }
    
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .event)
    }
    
    func createEvent(from reminder: Reminder, in calendar: EKCalendar) throws -> EKEvent {
        guard let dueDate = reminder.dueDate else {
            throw CalendarError.missingDueDate
        }
        
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = reminder.title
        event.notes = reminder.notes
        event.startDate = dueDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate) ?? dueDate
        
        // Set URL
        if let url = reminder.url {
            event.url = url
        }
        
        // Save the event
        do {
            try eventStore.save(event, commit: true)
        } catch let error as NSError {
            if error.domain == EKErrorDomain && error.code == 40 {
                // Ignore alarm-related errors
                return event
            }
            throw error
        }
        return event
    }
    
    func fetchExpiredEvents() throws -> [EKEvent] {
        let now = Date()
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .year, value: -1, to: now)!
        let endDate = now
        
        let predicate = EKEventStore().predicateForEvents(withStart: startDate,
                                                    end: endDate,
                                                    calendars: nil)
        return eventStore.events(matching: predicate)
    }
    
    func moveEventToCurrentWeek(_ event: EKEvent) throws {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: event.startDate)
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        
        // Find the next occurrence of the same weekday in the current week
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        
        guard let newStartDate = calendar.date(from: components) else {
            throw CalendarError.dateCalculationError
        }
        
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let newEndDate = newStartDate.addingTimeInterval(duration)
        
        // Update the event
        event.startDate = newStartDate
        event.endDate = newEndDate
        
        // Save the event
        do {
            try eventStore.save(event, commit: true)
        } catch let error as NSError {
            if error.domain == EKErrorDomain && error.code == 40 {
                // Ignore alarm-related errors
                return
            }
            throw error
        }
    }
    
    func deleteEvent(_ event: EKEvent) throws {
        try eventStore.remove(event, commit: true)
    }
}

enum CalendarError: Error {
    case missingDueDate
    case dateCalculationError
} 