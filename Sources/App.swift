import Foundation
import EventKit

struct App {
    let remindersManager: RemindersManager
    let calendarManager: CalendarManager
    let eventMerger: EventMerger
    
    init(remindersManager: RemindersManager = RemindersManager(),
         calendarManager: CalendarManager = CalendarManager(),
         eventMerger: EventMerger = EventMerger()) {
        self.remindersManager = remindersManager
        self.calendarManager = calendarManager
        self.eventMerger = eventMerger
    }
    
    func run() async throws {
        // Request access to Reminders and Calendar
        guard try await remindersManager.requestAccess(),
              try await calendarManager.requestAccess() else {
            print("Failed to get access to Reminders or Calendar")
            return
        }
        
        // 1. Convert reminders to calendar events
        let reminders = try await remindersManager.fetchIncompleteReminders()
        print("Found \(reminders.count) incomplete reminders")
        
        // Get default calendar
        guard let calendar = EKEventStore().defaultCalendarForNewEvents else {
            print("Failed to get default calendar")
            return
        }
        
        // Convert reminders to events
        for reminder in reminders {
            do {
                _ = try calendarManager.createEvent(from: reminder, in: calendar)
                print("Created event from reminder: \(reminder.title)")
            } catch {
                print("Failed to create event from reminder: \(reminder.title), error: \(error)")
            }
        }
        
        // 2. Handle expired events
        let expiredEvents = try calendarManager.fetchExpiredEvents()
        print("Found \(expiredEvents.count) expired events")
        
        for event in expiredEvents {
            do {
                try calendarManager.moveEventToCurrentWeek(event)
                print("Moved expired event to current week: \(event.title ?? "Untitled")")
            } catch {
                print("Failed to move expired event: \(event.title ?? "Untitled"), error: \(error)")
            }
        }
        
        // 3. Find and merge duplicate events
        let duplicates = eventMerger.findDuplicateEvents(expiredEvents)
        print("Found \(duplicates.count) groups of duplicate events")
        
        for (primary, duplicateEvents) in duplicates {
            let mergedEvent = eventMerger.mergeEvents(primary, with: duplicateEvents)
            print("Merged \(duplicateEvents.count + 1) events into: \(mergedEvent.title ?? "Untitled")")
            
            // Delete duplicate events
            for duplicate in duplicateEvents {
                do {
                    try calendarManager.deleteEvent(duplicate)
                } catch {
                    print("Failed to delete duplicate event: \(duplicate.title ?? "Untitled"), error: \(error)")
                }
            }
        }
    }
} 