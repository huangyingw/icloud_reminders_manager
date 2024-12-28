import Foundation
import EventKit

class MockEvent: EKEvent {
    private var mockTitle: String = ""
    private var mockStartDate: Date = Date()
    private var mockEndDate: Date = Date()
    private var mockCalendar: EKCalendar?
    private var mockNotes: String?
    private var mockURL: URL?
    
    override var title: String! {
        get { return mockTitle }
        set { mockTitle = newValue ?? "" }
    }
    
    override var startDate: Date! {
        get { return mockStartDate }
        set { mockStartDate = newValue ?? Date() }
    }
    
    override var endDate: Date! {
        get { return mockEndDate }
        set { mockEndDate = newValue ?? Date() }
    }
    
    override var calendar: EKCalendar? {
        get { return mockCalendar }
        set { mockCalendar = newValue }
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