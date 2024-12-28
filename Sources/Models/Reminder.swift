import Foundation
import EventKit

struct Reminder {
    let id: String
    let title: String
    let notes: String?
    let dueDate: Date?
    let alarms: [EKAlarm]?
    let url: URL?
    let participants: [String]?
    
    init(from ekReminder: EKReminder) {
        self.id = ekReminder.calendarItemIdentifier
        self.title = ekReminder.title
        self.notes = ekReminder.notes
        self.dueDate = ekReminder.dueDateComponents?.date
        self.alarms = ekReminder.alarms
        self.url = ekReminder.url
        self.participants = ekReminder.attendees?.map { $0.name ?? "" }
    }
} 