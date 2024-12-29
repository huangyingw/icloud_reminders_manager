import Foundation
import EventKit

public class MockEventStore: EKEventStore {
    public var shouldThrowError = false
    public var shouldGrantAccess = true
    public var mockEvents: [EKEvent] = []
    public var mockReminders: [EKReminder] = []
    public var mockFetchRemindersResponse: [EKReminder] = []
    private var mockSources: [EKSource] = []
    private var mockCalendars: [EKCalendar] = []
    
    public override var sources: [EKSource] {
        return mockSources
    }
    
    public func setMockSources(_ sources: [EKSource]) {
        mockSources = sources
    }
    
    public func createMockSource(title: String, type: EKSourceType) -> EKSource {
        let source = EKSource()
        source.setValue(title, forKey: "title")
        source.setValue(type.rawValue, forKey: "sourceType")
        return source
    }
    
    public func createMockCalendar(for entityType: EKEntityType) -> EKCalendar {
        let calendar = EKCalendar(for: entityType, eventStore: self)
        calendar.title = "Mock Calendar"
        mockCalendars.append(calendar)
        return calendar
    }
    
    public func createMockEvent() -> EKEvent {
        let event = EKEvent(eventStore: self)
        event.title = "Mock Event"
        event.startDate = Date()
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)!
        mockEvents.append(event)
        return event
    }
    
    public func createMockReminder() -> EKReminder {
        let reminder = EKReminder(eventStore: self)
        reminder.title = "Mock Reminder"
        reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: Date())
        mockReminders.append(reminder)
        return reminder
    }
    
    public override func requestAccess(to entityType: EKEntityType, completion: @escaping EKEventStoreRequestAccessCompletionHandler) {
        completion(shouldGrantAccess, nil)
    }
    
    public override func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1, userInfo: nil)
        }
    }
    
    public override func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1, userInfo: nil)
        }
        mockEvents.removeAll { $0 === event }
    }
    
    public override func fetchReminders(matching predicate: NSPredicate, completion: @escaping ([EKReminder]?) -> Void) -> Any {
        if shouldThrowError {
            completion(nil)
        } else {
            completion(mockFetchRemindersResponse)
        }
        return NSObject()
    }
    
    public override func save(_ reminder: EKReminder, commit: Bool) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1, userInfo: nil)
        }
    }
    
    public override func remove(_ reminder: EKReminder, commit: Bool) throws {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1, userInfo: nil)
        }
        mockReminders.removeAll { $0 === reminder }
    }
    
    public override func events(matching predicate: NSPredicate) -> [EKEvent] {
        return mockEvents
    }
    
    public override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars.filter { calendar in
            switch entityType {
            case .event:
                return calendar.allowedEntityTypes.contains(.event)
            case .reminder:
                return calendar.allowedEntityTypes.contains(.reminder)
            @unknown default:
                return false
            }
        }
    }
    
    public func mergeDuplicateEvents() async throws -> [EKEvent] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1, userInfo: nil)
        }
        
        // 按标题和时间分组
        var eventGroups: [String: [EKEvent]] = [:]
        for event in mockEvents {
            let title = event.title ?? ""
            let startDate = event.startDate.description
            let endDate = event.endDate.description
            let key = "\(title)_\(startDate)_\(endDate)"
            if eventGroups[key] == nil {
                eventGroups[key] = []
            }
            eventGroups[key]?.append(event)
        }
        
        // 合并重复事件
        var mergedEvents: [EKEvent] = []
        for (_, events) in eventGroups {
            if events.count > 1 {
                // 保留第一个事件，删除其他事件
                mergedEvents.append(events[0])
                for event in events.dropFirst() {
                    try remove(event, span: .thisEvent, commit: true)
                }
            } else {
                mergedEvents.append(events[0])
            }
        }
        
        return mergedEvents
    }
} 