import Foundation
import EventKit

class MockReminder: EKReminder {
    private var mockTitle: String = ""
    private var mockCalendar: EKCalendar?
    private var mockDueDateComponents: DateComponents?
    private var mockNotes: String?
    private var mockURL: URL?
    
    override var title: String! {
        get { return mockTitle }
        set { mockTitle = newValue ?? "" }
    }
    
    override var calendar: EKCalendar? {
        get { return mockCalendar }
        set { mockCalendar = newValue }
    }
    
    override var dueDateComponents: DateComponents? {
        get { return mockDueDateComponents }
        set { mockDueDateComponents = newValue }
    }
    
    override var notes: String? {
        get { return mockNotes }
        set { mockNotes = newValue }
    }
    
    override var url: URL? {
        get { return mockURL }
        set { mockURL = newValue }
    }
} 