import Foundation
import EventKit

enum TestHelpers {
    static func createTestCalendar(in eventStore: EKEventStore, name: String) throws -> EKCalendar {
        // 获取本地日历源
        let sources = eventStore.sources.filter { $0.sourceType == .local }
        guard let source = sources.first ?? eventStore.defaultCalendarForNewEvents?.source else {
            throw NSError(domain: "TestHelpers", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法获取日历源"])
        }
        
        // 创建新日历
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = name
        calendar.source = source
        
        // 保存日历
        try eventStore.saveCalendar(calendar, commit: true)
        
        return calendar
    }
    
    static func removeTestCalendar(_ calendar: EKCalendar, from eventStore: EKEventStore) throws {
        try eventStore.removeCalendar(calendar, commit: true)
    }
    
    static func createTestEvent(in calendar: EKCalendar, eventStore: EKEventStore, title: String, startDate: Date, endDate: Date) throws -> EKEvent {
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.calendar = calendar
        
        try eventStore.save(event, span: .thisEvent)
        
        return event
    }
    
    static func removeTestEvent(_ event: EKEvent, from eventStore: EKEventStore) throws {
        try eventStore.remove(event, span: .thisEvent)
    }
} 