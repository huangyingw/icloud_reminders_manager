import EventKit
import Foundation

class MockCalendar: Equatable {
    private var calendar: EKCalendar
    private var eventStore: EKEventStore
    private var _isSubscribed: Bool = false
    private var _allowsContentModifications: Bool = true
    private var _calendarType: EKCalendarType = .local
    private var _source: EKSource?
    private var _sourceTitle: String = ""
    private var _calendarIdentifier: String = UUID().uuidString
    
    var isSubscribed: Bool {
        get { return _isSubscribed }
    }
    
    var allowsContentModifications: Bool {
        get { return _allowsContentModifications }
    }
    
    var title: String {
        get { return calendar.title }
        set { calendar.title = newValue }
    }
    
    var type: EKCalendarType {
        get { return _calendarType }
    }
    
    var source: EKSource? {
        get { return _source }
        set {
            _source = newValue
            if let source = newValue as? MockSource {
                _sourceTitle = source.title
            }
        }
    }
    
    var sourceTitle: String {
        get { return _sourceTitle }
    }
    
    var calendarIdentifier: String {
        get { return _calendarIdentifier }
    }
    
    init(type: EKCalendarType, eventStore: EKEventStore) {
        self.eventStore = eventStore
        self.calendar = EKCalendar(for: .event, eventStore: eventStore)
        self._calendarType = type
    }
    
    func setIsSubscribed(_ value: Bool) {
        _isSubscribed = value
    }
    
    func setAllowsContentModifications(_ value: Bool) {
        _allowsContentModifications = value
    }
    
    func setSourceTitle(_ value: String) {
        _sourceTitle = value
        if let source = _source as? MockSource {
            source.setTitle(value)
        }
    }
    
    var ekCalendar: EKCalendar {
        get {
            calendar.title = title
            calendar.source = source
            return calendar
        }
    }
    
    static func == (lhs: MockCalendar, rhs: MockCalendar) -> Bool {
        return lhs.calendarIdentifier == rhs.calendarIdentifier
    }
} 