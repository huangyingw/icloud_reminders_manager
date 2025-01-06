import EventKit
import Foundation

class MockEventStore: EKEventStore {
    private var mockCalendars: [EKCalendar] = []
    private var mockEvents: [EKEvent] = []
    private var mockReminders: [EKReminder] = []
    private var mockSources: [EKSource] = []
    
    override var sources: [EKSource] {
        return mockSources
    }
    
    func createMockSource(title: String, type: EKSourceType) -> EKSource {
        let source = MockSource(title: title, type: type)
        mockSources.append(source)
        return source
    }
    
    func createMockCalendar(title: String, type: EKEntityType) -> EKCalendar {
        let calendar = EKCalendar(for: type, eventStore: self)
        calendar.title = title
        
        // 为日历创建一个源
        let sourceType: EKSourceType = type == .event ? .calDAV : .local
        let source = createMockSource(title: type == .event ? "iCloud" : "Local", type: sourceType)
        calendar.source = source
        
        mockCalendars.append(calendar)
        return calendar
    }
    
    func createMockEvent(title: String, startDate: Date, calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: self)
        event.title = title
        
        // 使用日历组件来设置事件的开始时间
        var cal = Calendar.current
        cal.firstWeekday = 2  // 星期一为一周的第一天
        
        // 获取并保留所有必要的组件
        var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday, .hour, .minute], from: startDate)
        
        // 确保weekday组件被正确保留
        if let weekday = components.weekday {
            components.weekday = weekday
        }
        
        // 创建新的日期
        if let newStartDate = cal.date(from: components) {
            event.startDate = newStartDate
            event.endDate = newStartDate.addingTimeInterval(3600)
        } else {
            // 如果日期创建失败，使用原始日期
            event.startDate = startDate
            event.endDate = startDate.addingTimeInterval(3600)
        }
        
        event.calendar = calendar
        mockEvents.append(event)
        return event
    }
    
    func createMockReminder(title: String, dueDate: Date, calendar: EKCalendar) -> EKReminder {
        let reminder = EKReminder(eventStore: self)
        reminder.title = title
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        reminder.calendar = calendar
        mockReminders.append(reminder)
        return reminder
    }
    
    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        switch entityType {
        case .event:
            return mockCalendars.filter { $0.allowsContentModifications }
        case .reminder:
            return mockCalendars.filter { !$0.allowsContentModifications }
        @unknown default:
            return []
        }
    }
    
    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
    
    override func save(_ event: EKEvent, span: EKSpan) throws {
        if !mockEvents.contains(event) {
            mockEvents.append(event)
        }
    }
    
    override func remove(_ event: EKEvent, span: EKSpan) throws {
        if let index = mockEvents.firstIndex(of: event) {
            mockEvents.remove(at: index)
        }
    }
    
    override func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        if !mockCalendars.contains(where: { $0 === calendar }) {
            mockCalendars.append(calendar)
        }
    }
    
    override func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        if let index = mockCalendars.firstIndex(where: { $0 === calendar }) {
            mockCalendars.remove(at: index)
        }
    }
    
    func getAllEvents() -> [EKEvent] {
        return mockEvents
    }
    
    override func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        completion(mockReminders)
        return NSObject()
    }
    
    override func save(_ reminder: EKReminder, commit: Bool) throws {
        if !mockReminders.contains(reminder) {
            mockReminders.append(reminder)
        }
    }
    
    override func remove(_ reminder: EKReminder, commit: Bool) throws {
        if let index = mockReminders.firstIndex(of: reminder) {
            mockReminders.remove(at: index)
        }
    }
    
    func getCalendarByTitle(_ title: String) -> EKCalendar? {
        return mockCalendars.first { $0.title == title }
    }
    
    func getCalendarByIdentifier(_ identifier: String) -> EKCalendar? {
        return mockCalendars.first { $0.calendarIdentifier == identifier }
    }
    
    func addMockCalendar(_ calendar: EKCalendar) {
        mockCalendars.append(calendar)
    }
    
    func addMockEvent(_ event: EKEvent) {
        mockEvents.append(event)
    }
    
    func clearMocks() {
        mockCalendars.removeAll()
        mockEvents.removeAll()
        mockReminders.removeAll()
        mockSources.removeAll()
    }
}

class MockSource: EKSource {
    private var mockTitle: String
    private let mockSourceType: EKSourceType
    
    init(title: String, type: EKSourceType) {
        self.mockTitle = title
        self.mockSourceType = type
        super.init()
    }
    
    override var title: String {
        return mockTitle
    }
    
    override var sourceType: EKSourceType {
        return mockSourceType
    }
    
    func setTitle(_ value: String) {
        mockTitle = value
    }
} 