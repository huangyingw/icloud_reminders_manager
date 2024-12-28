import Foundation
import EventKit

class RemindersManager {
    private let eventStore: EKEventStore
    
    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }
    
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .reminder)
    }
    
    func fetchIncompleteReminders() async throws -> [Reminder] {
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    let customReminders = reminders.map { Reminder(from: $0) }
                    continuation.resume(returning: customReminders)
                } else {
                    continuation.resume(throwing: ReminderError.fetchFailed)
                }
            }
        }
    }
    
    func markAsCompleted(_ reminder: Reminder) async throws {
        let predicate = eventStore.predicateForReminders(in: nil)
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders,
                   let ekReminder = reminders.first(where: { $0.title == reminder.title && $0.notes == reminder.notes }) {
                    ekReminder.isCompleted = true
                    do {
                        try self.eventStore.save(ekReminder, commit: true)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } else {
                    continuation.resume(throwing: ReminderError.notFound)
                }
            }
        }
    }
}

enum ReminderError: Error {
    case fetchFailed
    case notFound
} 