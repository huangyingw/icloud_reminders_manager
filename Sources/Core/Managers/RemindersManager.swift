import Foundation
import EventKit

public class RemindersManager {
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    public func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .reminder)
    }
    
    public func fetchIncompleteReminders() async throws -> [EKReminder] {
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: nil,
            calendars: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: NSError(domain: "RemindersManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reminders"]))
                }
            }
        }
    }
    
    public func markAsCompleted(_ reminder: EKReminder) async throws {
        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)
    }
} 