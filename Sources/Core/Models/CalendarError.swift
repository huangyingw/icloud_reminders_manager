import Foundation

public enum CalendarError: Error, Equatable {
    case noCalendarsAvailable
    case noEventsFound
    case noRemindersFound
    case accessDenied
    case unknown(Error)
    
    public static func == (lhs: CalendarError, rhs: CalendarError) -> Bool {
        switch (lhs, rhs) {
        case (.noCalendarsAvailable, .noCalendarsAvailable),
             (.noEventsFound, .noEventsFound),
             (.noRemindersFound, .noRemindersFound),
             (.accessDenied, .accessDenied):
            return true
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
} 