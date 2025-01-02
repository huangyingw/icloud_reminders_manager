import EventKit
import Foundation

public class CalendarManager {
    internal let config: Config
    internal let eventStore: EKEventStore
    internal let logger: FileLogger
    
    public init(config: Config, eventStore: EKEventStore, logger: FileLogger) {
        self.config = config
        self.eventStore = eventStore
        self.logger = logger
    }
    
    public func getICloudCalendars() -> [EKCalendar] {
        let calendars = eventStore.calendars(for: .event)
        return calendars.filter { calendar in
            guard let source = calendar.source else { return false }
            return source.sourceType == .calDAV
        }
    }
    
    public func getTargetCalendar() throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        guard let targetCalendar = calendars.first(where: { $0.title == config.calendar.targetCalendarName }) else {
            throw CalendarError.targetCalendarNotFound
        }
        return targetCalendar
    }
    
    public func isCalendarEmpty(_ calendar: EKCalendar) -> Bool {
        let startDate = Date.distantPast
        let endDate = Date.distantFuture
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: [calendar])
        let events = eventStore.events(matching: predicate)
        return events.isEmpty
    }
    
    public func deleteEmptyCalendar(_ calendar: EKCalendar) throws {
        // 不能删除目标日历
        if calendar.title == config.calendar.targetCalendarName {
            return
        }
        
        // 检查日历是否为空
        guard isCalendarEmpty(calendar) else {
            logger.warning("日历 '\(calendar.title)' 不为空，无法删除")
            return
        }
        
        // 删除空日历
        try eventStore.removeCalendar(calendar, commit: true)
        logger.info("已删除空日历 '\(calendar.title)'")
    }
    
    public func moveEventToTargetCalendar(_ event: EKEvent) async throws {
        let targetCalendar = try getTargetCalendar()
        
        // 如果事件已经在目标日历中，不需要移动
        if event.calendar == targetCalendar {
            return
        }
        
        // 创建新事件
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = event.title
        newEvent.startDate = event.startDate
        newEvent.endDate = event.endDate
        newEvent.calendar = targetCalendar
        
        // 复制其他属性
        newEvent.notes = event.notes
        newEvent.location = event.location
        newEvent.url = event.url
        newEvent.isAllDay = event.isAllDay
        
        // 复制重复规则
        if let rules = event.recurrenceRules {
            newEvent.recurrenceRules = rules
        }
        
        // 保存新事件
        try eventStore.save(newEvent, span: .thisEvent)
        
        // 删除原事件
        try eventStore.remove(event, span: .thisEvent)
        
        logger.info("已将事件 '\(event.title ?? "未命名事件")' 从 '\(event.calendar.title)' 移动到 '\(targetCalendar.title)'")
    }
} 