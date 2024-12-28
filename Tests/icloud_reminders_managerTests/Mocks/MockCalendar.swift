import Foundation
import EventKit

class MockCalendar: EKCalendar {
    private var mockTitle: String = ""
    private var mockSource: EKSource?
    private var mockType: EKCalendarType
    private var mockAllowedEntityTypes: EKEntityMask
    private var mockCalendarIdentifier: String
    
    init(type: EKEntityType, eventStore: EKEventStore) {
        self.mockType = type == .event ? .local : .subscription
        self.mockAllowedEntityTypes = type == .event ? .event : .reminder
        self.mockCalendarIdentifier = UUID().uuidString
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var title: String {
        get { return mockTitle }
        set { mockTitle = newValue }
    }
    
    override var source: EKSource? {
        get { return mockSource }
        set { mockSource = newValue }
    }
    
    override var type: EKCalendarType {
        return mockType
    }
    
    override var allowedEntityTypes: EKEntityMask {
        return mockAllowedEntityTypes
    }
    
    override var calendarIdentifier: String {
        return mockCalendarIdentifier
    }
} 