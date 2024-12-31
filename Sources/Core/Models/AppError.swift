import Foundation

public enum AppError: Error {
    case noCalendarsAvailable
    case noEventsFound
    case noRemindersFound
    case accessDenied
    case unknown(Error)
} 