import Foundation
import EventKit
import icloud_reminders_manager_core

@main
struct App {
    static func main() async throws {
        // Initialize managers
        let eventStore = EKEventStore()
        let calendarManager = CalendarManager(eventStore: eventStore)
        let eventMerger = EventMerger(eventStore: eventStore)
        let remindersManager = RemindersManager(eventStore: eventStore)
        
        // Request access to Calendar and Reminders
        guard try await calendarManager.requestAccess(),
              try await remindersManager.requestAccess() else {
            print("Failed to get access to Calendar and Reminders")
            return
        }
        
        // Fetch incomplete reminders
        let reminders = try await remindersManager.fetchIncompleteReminders()
        print("Found \(reminders.count) incomplete reminders")
        
        // Convert reminders to events
        for reminder in reminders {
            let event = try await calendarManager.createEventFromReminder(reminder)
            print("Created event: \(event.title ?? "Untitled")")
            try await remindersManager.markAsCompleted(reminder)
        }
        
        // Move expired events to current week
        try await calendarManager.moveExpiredEventsToCurrentWeek()
        
        // Delete expired recurring events
        try await calendarManager.deleteExpiredRecurringEvents()
    }
} 