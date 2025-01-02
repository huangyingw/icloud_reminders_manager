import EventKit
import Foundation

class MockEventStore: EKEventStore {
    private var mockCalendars: [EKCalendar] = []
    private var mockReminders: [EKReminder] = []
    private var mockEvents: [EKEvent] = []
    private var mockSources: [EKSource] = []
    
    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars.filter { calendar in
            switch entityType {
            case .event:
                return true // 在测试中，我们假设所有日历都支持事件
            case .reminder:
                return true // 在测试中，我们假设所有日历都支持提醒
            @unknown default:
                return false
            }
        }
    }
    
    override func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        completion(mockReminders)
        return NSObject()
    }
    
    override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
    
    override func save(_ event: EKEvent, span: EKSpan) throws {
        mockEvents.append(event)
    }
    
    override func remove(_ event: EKEvent, span: EKSpan) throws {
        if let index = mockEvents.firstIndex(of: event) {
            mockEvents.remove(at: index)
        }
    }
    
    override func remove(_ reminder: EKReminder, commit: Bool) throws {
        if let index = mockReminders.firstIndex(of: reminder) {
            mockReminders.remove(at: index)
        }
    }
    
    override func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        mockCalendars.append(calendar)
    }
    
    override func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        if let index = mockCalendars.firstIndex(of: calendar) {
            mockCalendars.remove(at: index)
        }
    }
    
    override var sources: [EKSource] {
        return mockSources
    }
    
    override func predicateForEvents(withStart startDate: Date, end endDate: Date, calendars: [EKCalendar]?) -> NSPredicate {
        return NSPredicate(value: true)
    }
    
    override func predicateForReminders(in calendars: [EKCalendar]?) -> NSPredicate {
        return NSPredicate(value: true)
    }
    
    // Helper methods for testing
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
        event.endDate = startDate.addingTimeInterval(3600) // 1 hour duration
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
    
    func createMockSource(title: String, type: EKSourceType) -> EKSource {
        let source = EKSource()
        source.setValue(title, forKey: "title")
        source.setValue(type.rawValue, forKey: "sourceType")
        mockSources.append(source)
        return source
    }
    
    func getAllEvents() -> [EKEvent] {
        return mockEvents
    }
    
    var savedEvents: [(event: EKEvent, span: EKSpan)] {
        return mockEvents.map { ($0, .thisEvent) }
    }
    
    var removedEvents: [EKEvent] {
        return []
    }
} 