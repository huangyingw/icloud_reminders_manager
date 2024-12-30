import Foundation

public enum AppError: Error {
    case noCalendarsAvailable
    case noReminderListsAvailable
    case noRemindersAvailable
    case accessDenied
    case calendarAccessDenied
    case reminderAccessDenied
} 