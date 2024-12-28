import Foundation
import EventKit

class MockEvent: EKEvent {
    var mockTitle: String?
    var mockStartDate: Date!
    var mockEndDate: Date!
    var mockNotes: String?
    var mockURL: URL?
    var mockLocation: String?
    var mockCalendar: EKCalendar?
    var mockAlarms: [EKAlarm]?
    var mockAttendees: [EKParticipant]?
    var mockRecurrenceRules: [EKRecurrenceRule]?
    
    override var title: String? {
        get { mockTitle }
        set { mockTitle = newValue }
    }
    
    override var startDate: Date! {
        get { mockStartDate }
        set { mockStartDate = newValue }
    }
    
    override var endDate: Date! {
        get { mockEndDate }
        set { mockEndDate = newValue }
    }
    
    override var notes: String? {
        get { mockNotes }
        set { mockNotes = newValue }
    }
    
    override var url: URL? {
        get { mockURL }
        set { mockURL = newValue }
    }
    
    override var location: String? {
        get { mockLocation }
        set { mockLocation = newValue }
    }
    
    override var calendar: EKCalendar? {
        get { mockCalendar }
        set { mockCalendar = newValue }
    }
    
    override var alarms: [EKAlarm]? {
        get { mockAlarms }
        set { mockAlarms = newValue }
    }
    
    override var attendees: [EKParticipant]? {
        get { mockAttendees }
        set { mockAttendees = newValue }
    }
    
    override var recurrenceRules: [EKRecurrenceRule]? {
        get { mockRecurrenceRules }
        set { mockRecurrenceRules = newValue }
    }
    
    override func addAlarm(_ alarm: EKAlarm) {
        if mockAlarms == nil {
            mockAlarms = []
        }
        mockAlarms?.append(alarm)
    }
    
    override func removeAlarm(_ alarm: EKAlarm) {
        mockAlarms?.removeAll { $0 === alarm }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
} 