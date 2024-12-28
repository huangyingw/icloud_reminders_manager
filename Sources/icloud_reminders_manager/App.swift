import Foundation
import EventKit

class App {
    private let remindersManager: RemindersManager
    private let calendarManager: CalendarManager
    private let eventMerger: EventMerger
    private let eventStore: EKEventStore
    
    init(remindersManager: RemindersManager = RemindersManager(),
         eventStore: EKEventStore = EKEventStore(),
         calendarManager: CalendarManager? = nil,
         eventMerger: EventMerger = EventMerger()) {
        self.eventStore = eventStore
        self.remindersManager = remindersManager
        self.calendarManager = calendarManager ?? CalendarManager(eventStore: eventStore)
        self.eventMerger = eventMerger
    }
    
    func run() async throws {
        // 1. Handle reminders
        let hasReminderAccess = try await remindersManager.requestAccess()
        guard hasReminderAccess else {
            print("No access to reminders")
            return
        }
        
        let hasCalendarAccess = try await calendarManager.requestAccess()
        guard hasCalendarAccess else {
            print("No access to calendar")
            return
        }
        
        let reminders = try await remindersManager.fetchIncompleteReminders()
        print("Found \(reminders.count) incomplete reminders")
        
        // Get default calendar for new events
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
            print("No default calendar available")
            return
        }
        
        for reminder in reminders {
            do {
                // Create a new EKReminder from our custom Reminder type
                let ekReminder = EKReminder(eventStore: eventStore)
                ekReminder.title = reminder.title
                ekReminder.notes = reminder.notes
                ekReminder.calendar = defaultCalendar
                if let dueDate = reminder.dueDate {
                    ekReminder.dueDateComponents = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: dueDate
                    )
                }
                
                // Create event from the EKReminder
                _ = try await calendarManager.createEventFromReminder(ekReminder)
                print("Created event from reminder: \(reminder.title)")
                
                // Mark the original reminder as completed
                try await remindersManager.markAsCompleted(reminder)
            } catch {
                print("Error creating event from reminder: \(error)")
            }
        }
        
        // 2. Handle events
        let calendar = Calendar.current
        let now = Date()
        let oneWeekAgo = calendar.date(byAdding: .weekOfYear, value: -1, to: now)!
        let predicate = eventStore.predicateForEvents(withStart: oneWeekAgo,
                                                    end: now,
                                                    calendars: nil)
        let events = eventStore.events(matching: predicate)
        print("Found \(events.count) events in the past week")
        
        // Find and merge duplicate events
        let duplicates = eventMerger.findDuplicateEvents(events)
        for (primary, duplicateEvents) in duplicates {
            do {
                let merged = eventMerger.mergeEvents(primary, with: duplicateEvents)
                try eventStore.save(merged, span: .thisEvent)
                
                // Remove the duplicate events
                for duplicate in duplicateEvents {
                    try eventStore.remove(duplicate, span: .thisEvent)
                }
                
                print("Merged \(duplicateEvents.count + 1) events into: \(merged.title ?? "Untitled")")
            } catch {
                print("Error merging events: \(error)")
            }
        }
    }
} 