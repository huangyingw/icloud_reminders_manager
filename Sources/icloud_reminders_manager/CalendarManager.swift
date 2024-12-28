import Foundation
import EventKit

class CalendarManager {
    private let eventStore: EKEventStore
    
    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }
    
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .event)
    }
    
    func createEventFromReminder(_ reminder: EKReminder) async throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = reminder.title
        event.notes = reminder.notes
        
        if let dueDate = reminder.dueDateComponents?.date {
            event.startDate = dueDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate)!
        }
        
        event.calendar = reminder.calendar ?? eventStore.defaultCalendarForNewEvents
        try eventStore.save(event, span: .thisEvent)
        
        return event
    }
    
    func moveEventToCurrentWeek(_ event: EKEvent) async throws -> EKEvent {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let startOfWeek = calendar.date(byAdding: .day, value: 1 - weekday, to: now)!
        
        // Calculate the same weekday and time in the current week
        let eventWeekday = calendar.component(.weekday, from: event.startDate)
        let daysToAdd = eventWeekday - calendar.component(.weekday, from: startOfWeek)
        
        let newStartDate = calendar.date(byAdding: .day, value: daysToAdd, to: startOfWeek)!
        let newStartTime = calendar.date(
            bySettingHour: calendar.component(.hour, from: event.startDate),
            minute: calendar.component(.minute, from: event.startDate),
            second: calendar.component(.second, from: event.startDate),
            of: newStartDate
        )!
        
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let newEndTime = newStartTime.addingTimeInterval(duration)
        
        let movedEvent = EKEvent(eventStore: eventStore)
        movedEvent.title = event.title
        movedEvent.notes = event.notes
        movedEvent.startDate = newStartTime
        movedEvent.endDate = newEndTime
        movedEvent.calendar = event.calendar
        
        // Copy other properties
        movedEvent.url = event.url
        movedEvent.location = event.location
        movedEvent.alarms = event.alarms
        movedEvent.recurrenceRules = event.recurrenceRules
        
        try eventStore.save(movedEvent, span: .thisEvent)
        try eventStore.remove(event, span: .thisEvent)
        
        return movedEvent
    }
} 