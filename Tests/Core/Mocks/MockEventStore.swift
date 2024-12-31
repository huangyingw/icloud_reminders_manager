import EventKit
import Foundation

class MockEventStore: EKEventStore {
    var mockCalendars: [EKCalendar] = []
    var mockReminders: [EKReminder] = []
    var mockEvents: [EKEvent] = []
    var mockSources: [EKSource] = []
    
    var savedEvents: [(event: EKEvent, span: EKSpan)] = []
    var savedReminders: [(reminder: EKReminder, commit: Bool)] = []
    var removedEvents: [EKEvent] = []
    var removedCalendars: [EKCalendar] = []
    var requestedAccess: Set<EKEntityType> = []
    var shouldGrantAccess: Bool = true
    private var nextEventIdentifier = 1
    private var eventIdentifiers: [EKEvent: String] = [:]
    
    override init() {
        super.init()
    }
    
    override func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        requestedAccess.insert(entityType)
        return shouldGrantAccess
    }
    
    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars
    }
    
    func createMockSource(title: String, type: EKSourceType) -> EKSource {
        let source = EKSource()
        source.setValue(title, forKey: "title")
        source.setValue(type.rawValue, forKey: "sourceType")
        mockSources.append(source)
        return source
    }
    
    func createMockCalendar(title: String, type: EKEntityType = .event) -> EKCalendar {
        let calendar = EKCalendar(for: type, eventStore: self)
        calendar.title = title
        mockCalendars.append(calendar)
        return calendar
    }
    
    func createMockEvent(title: String, startDate: Date, calendar: EKCalendar) -> EKEvent {
        let event = EKEvent(eventStore: self)
        event.title = title
        event.startDate = startDate
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate)!
        event.calendar = calendar
        eventIdentifiers[event] = "\(nextEventIdentifier)"
        nextEventIdentifier += 1
        mockEvents.append(event)
        return event
    }
    
    func createMockReminder(title: String, dueDate: Date?, calendar: EKCalendar) -> EKReminder {
        let reminder = EKReminder(eventStore: self)
        reminder.title = title
        reminder.dueDateComponents = dueDate.map { Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0) }
        reminder.calendar = calendar
        mockReminders.append(reminder)
        return reminder
    }
    
    override func save(_ event: EKEvent, span: EKSpan) throws {
        savedEvents.append((event: event, span: span))
        
        // 如果事件已存在，更新它；否则添加新事件
        if let index = mockEvents.firstIndex(where: { eventIdentifiers[$0] == eventIdentifiers[event] }) {
            mockEvents[index] = event
        } else {
            // 为新事件生成标识符
            if eventIdentifiers[event] == nil {
                eventIdentifiers[event] = "\(nextEventIdentifier)"
                nextEventIdentifier += 1
            }
            mockEvents.append(event)
        }
    }
    
    override func save(_ reminder: EKReminder, commit: Bool) throws {
        savedReminders.append((reminder: reminder, commit: commit))
    }
    
    override func remove(_ event: EKEvent, span: EKSpan) throws {
        removedEvents.append(event)
        // 从 mockEvents 中移除事件
        if let index = mockEvents.firstIndex(where: { eventIdentifiers[$0] == eventIdentifiers[event] }) {
            mockEvents.remove(at: index)
        }
    }
    
    override func remove(_ reminder: EKReminder, commit: Bool) throws {
        // 不需要实现，因为我们不会在测试中删除提醒
    }
    
    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
    
    override func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        completion(mockReminders)
        return NSObject()
    }
} 