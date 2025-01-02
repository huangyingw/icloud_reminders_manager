import Foundation

public enum CalendarError: Error {
    case targetCalendarNotFound
    case sourceCalendarNotFound
    case failedToCreateCalendar
    case failedToSaveEvent
    case failedToDeleteEvent
    case failedToDeleteCalendar
    case failedToMoveEvent
    case failedToProcessReminder
    case failedToDeleteReminder
    case failedToGetCalendars
    case failedToGetEvents
    case failedToGetReminders
} 