import Foundation
import EventKit

struct Reminder {
    let title: String
    let notes: String?
    let dueDate: Date?
    let isCompleted: Bool
    
    init(title: String, notes: String? = nil, dueDate: Date? = nil, isCompleted: Bool = false) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
    
    init(from ekReminder: EKReminder) {
        self.title = ekReminder.title
        self.notes = ekReminder.notes
        self.dueDate = ekReminder.dueDateComponents?.date
        self.isCompleted = ekReminder.isCompleted
    }
} 