import Foundation
import EventKit

public class CalendarManager {
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    public func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .event)
    }
    
    public func createEventFromReminder(_ reminder: EKReminder) async throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = reminder.title
        event.notes = reminder.notes
        event.startDate = reminder.dueDateComponents?.date ?? Date()
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.calendar = reminder.calendar
        
        try eventStore.save(event, span: .thisEvent, commit: true)
        return event
    }
    
    public func moveEventToCurrentWeek(_ event: EKEvent) async throws {
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.startOfWeek(for: now)
        
        // If the event is already in the current week or future, don't move it
        if event.startDate >= currentWeekStart {
            return
        }
        
        // Calculate the day of week and time components
        let dayOfWeek = calendar.component(.weekday, from: event.startDate)
        let hour = calendar.component(.hour, from: event.startDate)
        let minute = calendar.component(.minute, from: event.startDate)
        
        // Create the new start date in the current week
        var newStartDate = currentWeekStart
        newStartDate = calendar.date(bySetting: .weekday, value: dayOfWeek, of: newStartDate)!
        newStartDate = calendar.date(bySetting: .hour, value: hour, of: newStartDate)!
        newStartDate = calendar.date(bySetting: .minute, value: minute, of: newStartDate)!
        
        // If the new start date is before the current week start, move it to the next week
        if newStartDate < currentWeekStart {
            newStartDate = calendar.date(byAdding: .weekOfYear, value: 1, to: newStartDate)!
        }
        
        // Keep the same duration
        let duration = event.endDate.timeIntervalSince(event.startDate)
        
        event.startDate = newStartDate
        event.endDate = event.startDate.addingTimeInterval(duration)
        
        try eventStore.save(event, span: .thisEvent, commit: true)
        print("Moved event to current week: \(event.title ?? "Untitled")")
    }
    
    public func moveExpiredEventsToCurrentWeek() async throws {
        let calendar = Calendar.current
        let now = Date()
        let predicate = eventStore.predicateForEvents(
            withStart: calendar.date(byAdding: .year, value: -1, to: now)!,
            end: now,
            calendars: nil
        )
        
        let expiredEvents = eventStore.events(matching: predicate)
        for event in expiredEvents {
            if event.recurrenceRules?.isEmpty ?? true {
                try await moveEventToCurrentWeek(event)
            }
        }
    }
    
    public func deleteExpiredRecurringEvents() async throws {
        let now = Date()
        let predicate = eventStore.predicateForEvents(
            withStart: Calendar.current.date(byAdding: .year, value: -1, to: now)!,
            end: now,
            calendars: nil
        )
        
        let expiredEvents = eventStore.events(matching: predicate)
        for event in expiredEvents {
            if let recurrenceRules = event.recurrenceRules,
               !recurrenceRules.isEmpty,
               let lastRecurrence = recurrenceRules.first?.recurrenceEnd?.endDate,
               lastRecurrence < now {
                try eventStore.remove(event, span: .futureEvents, commit: true)
                print("Deleted expired recurring event: \(event.title ?? "Untitled")")
            }
        }
    }
}

extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let components = self.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: components)!
    }
} 