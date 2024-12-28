import Foundation
import EventKit

class CalendarManager {
    private let eventStore: EKEventStore
    
    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .event)
    }
    
    func createEventFromReminder(_ reminder: EKReminder) async throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = reminder.title
        event.notes = reminder.notes
        event.calendar = reminder.calendar
        
        if let dueDate = reminder.dueDateComponents?.date {
            event.startDate = dueDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate)!
        } else {
            event.startDate = Date()
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)!
        }
        
        try eventStore.save(event, span: .thisEvent)
        return event
    }
    
    func moveEventToCurrentWeek(_ event: EKEvent) async throws -> EKEvent {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.startOfWeek(for: now)
        
        // Calculate the day of week for both dates
        let eventDayOfWeek = calendar.component(.weekday, from: event.startDate)
        let targetDayOfWeek = calendar.component(.weekday, from: currentWeekStart)
        
        // Calculate the difference in days needed to move the event
        let daysDifference = eventDayOfWeek - targetDayOfWeek
        
        // Create new dates for the event in the current week
        let newStartDate = calendar.date(byAdding: .day, value: daysDifference, to: currentWeekStart)!
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let newEndDate = newStartDate.addingTimeInterval(duration)
        
        // Update the event
        event.startDate = newStartDate
        event.endDate = newEndDate
        
        try eventStore.save(event, span: .thisEvent)
        return event
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
} 