import Foundation
import EventKit

public struct Reminder {
    public let title: String
    public let notes: String?
    public let dueDate: Date?
    public let isCompleted: Bool
    
    public init(title: String, notes: String? = nil, dueDate: Date? = nil, isCompleted: Bool = false) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
    }
    
    public init(from ekReminder: EKReminder) {
        self.title = ekReminder.title
        self.notes = ekReminder.notes
        self.dueDate = ekReminder.dueDateComponents?.date
        self.isCompleted = ekReminder.isCompleted
    }
} 