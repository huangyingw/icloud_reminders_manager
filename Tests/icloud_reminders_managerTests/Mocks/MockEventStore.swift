import EventKit
@testable import icloud_reminders_manager

class MockEventStore: EKEventStore {
    private var mockEvents: [EKEvent] = []
    private var mockReminders: [EKReminder] = []
    private var mockSources: [EKSource] = []
    private var mockCalendars: [(calendar: EKCalendar, entityType: EKEntityType)] = []
    
    // 记录方法调用
    var savedEvents: [(event: EKEvent, span: EKSpan)] = []
    var removedEvents: [(event: EKEvent, span: EKSpan)] = []
    var savedReminders: [(reminder: EKReminder, span: EKSpan)] = []
    var removedReminders: [(reminder: EKReminder, span: EKSpan)] = []
    
    func setMockSources(_ sources: [EKSource]) {
        mockSources = sources
    }
    
    override var sources: [EKSource] {
        return mockSources
    }
    
    func createMockSource(title: String, type: EKSourceType) -> EKSource {
        let source = MockSource(eventStore: self)
        source.mockTitle = title
        source.mockSourceType = type
        mockSources.append(source)
        return source
    }
    
    func createMockCalendar(for entityType: EKEntityType, title: String, source: EKSource) -> EKCalendar {
        let calendar = EKCalendar(for: entityType, eventStore: self)
        calendar.title = title
        calendar.source = source
        mockCalendars.append((calendar: calendar, entityType: entityType))
        return calendar
    }
    
    func createMockEvent(title: String, startDate: Date, calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: self)
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        event.calendar = calendar
        mockEvents.append(event)
        return event
    }
    
    func createMockReminder(title: String, dueDate: Date? = nil, calendar: EKCalendar) -> EKReminder {
        let reminder = EKReminder(eventStore: self)
        reminder.title = title
        if let dueDate = dueDate {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
        }
        reminder.calendar = calendar
        mockReminders.append(reminder)
        return reminder
    }
    
    override func save(_ object: EKObject, span: EKSpan) throws {
        // 记录保存操作
        if let event = object as? EKEvent {
            savedEvents.append((event: event, span: span))
            if !mockEvents.contains(where: { $0 === event }) {
                mockEvents.append(event)
            }
        } else if let reminder = object as? EKReminder {
            savedReminders.append((reminder: reminder, span: span))
            if !mockReminders.contains(where: { $0 === reminder }) {
                mockReminders.append(reminder)
            }
        }
    }
    
    override func remove(_ object: EKObject, span: EKSpan) throws {
        // 记录删除操作
        if let event = object as? EKEvent {
            removedEvents.append((event: event, span: span))
            mockEvents.removeAll { $0 === event }
        } else if let reminder = object as? EKReminder {
            removedReminders.append((reminder: reminder, span: span))
            mockReminders.removeAll { $0 === reminder }
        } else if let calendar = object as? EKCalendar {
            mockCalendars.removeAll { $0.calendar === calendar }
        }
    }
    
    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars.filter { $0.entityType == entityType }.map { $0.calendar }
    }
    
    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        // 如果是日历事件的谓词，返回对应日历的事件
        if let calendarPredicate = predicate as? EKCalendarPredicate,
           let calendars = calendarPredicate.calendars {
            return mockEvents.filter { event in
                calendars.contains(event.calendar!)
            }
        }
        return mockEvents
    }
    
    @discardableResult
    override func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        // 如果是日历提醒的谓词，返回对应日历的提醒
        if let calendarPredicate = predicate as? EKCalendarPredicate,
           let calendars = calendarPredicate.calendars {
            let reminders = mockReminders.filter { reminder in
                calendars.contains(reminder.calendar)
            }
            completion(reminders)
        } else {
            completion(mockReminders)
        }
        return NSObject()
    }
    
    override func predicateForEvents(withStart startDate: Date?, end endDate: Date?, calendars: [EKCalendar]?) -> NSPredicate {
        return EKCalendarPredicate(calendars: calendars.map(Set.init))
    }
    
    override func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        return EKCalendarPredicate(calendars: calendars.map(Set.init))
    }
}

class MockSource: EKSource {
    var mockTitle: String = ""
    var mockSourceType: EKSourceType = .local
    weak var mockEventStore: EKEventStore?
    
    init(eventStore: EKEventStore) {
        self.mockEventStore = eventStore
        super.init()
    }
    
    override var title: String {
        return mockTitle
    }
    
    override var sourceType: EKSourceType {
        return mockSourceType
    }
    
    override func calendars(for entityType: EKEntityType) -> Set<EKCalendar> {
        guard let eventStore = mockEventStore as? MockEventStore else {
            return Set()
        }
        let calendars = eventStore.calendars(for: entityType).filter { $0.source === self }
        return Set(calendars)
    }
}

// 用于测试的谓词类
class EKCalendarPredicate: NSPredicate {
    let calendars: Set<EKCalendar>?
    
    init(calendars: Set<EKCalendar>?) {
        self.calendars = calendars
        super.init()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
} 