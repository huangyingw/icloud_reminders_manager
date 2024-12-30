import Foundation
import EventKit

public class RemindersManager {
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    /// 获取所有提醒列表
    public func getReminderLists() -> [EKCalendar] {
        return eventStore.calendars(for: .reminder)
    }
    
    /// 获取指定提醒列表中的所有提醒
    public func getReminders(from list: EKCalendar) async throws -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: [list])
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: ReminderError.fetchFailed)
                }
            }
        }
    }
    
    /// 获取指定提醒列表中的过期提醒
    public func getExpiredReminders(from list: EKCalendar) async throws -> [EKReminder] {
        let reminders = try await getReminders(from: list)
        let now = Date()
        return reminders.filter { reminder in
            guard let dueDate = reminder.dueDateComponents?.date else { return false }
            return dueDate < now
        }
    }
}

public enum ReminderError: Error {
    case fetchFailed
} 