import Foundation
import EventKit

class RemindersManager {
    private let eventStore: EventStoreProtocol
    
    init(eventStore: EventStoreProtocol = EKEventStore()) {
        self.eventStore = eventStore
    }
    
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .reminder)
    }
    
    func fetchIncompleteReminders() async throws -> [Reminder] {
        let predicate = NSPredicate(format: "completed = false")
        let semaphore = DispatchSemaphore(value: 0)
        var fetchedReminders: [EKReminder]?
        var fetchError: Error?
        
        _ = eventStore.fetchReminders(matching: predicate) { reminders in
            fetchedReminders = reminders
            semaphore.signal()
        }
        
        _ = semaphore.wait(timeout: .now() + 5)
        
        if let error = fetchError {
            throw error
        }
        
        guard let reminders = fetchedReminders else {
            return []
        }
        
        return reminders.map { Reminder(from: $0) }
    }
    
    func deleteReminder(_ reminder: EKReminder) throws {
        try eventStore.remove(reminder, commit: true)
    }
} 