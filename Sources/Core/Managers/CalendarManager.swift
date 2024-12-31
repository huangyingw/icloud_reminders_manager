import EventKit
import Logging

public class CalendarManager {
    internal let eventStore: EKEventStore
    internal let logger: Logger
    internal let config: Config
    
    public init(eventStore: EKEventStore, config: Config, logger: Logger) {
        self.eventStore = eventStore
        self.config = config
        self.logger = logger
    }
    
    public func getICloudCalendars() -> [EKCalendar] {
        let calendars = eventStore.calendars(for: .event)
        logger.info("找到 \(calendars.count) 个日历")
        
        let filteredCalendars = calendars.filter { calendar in
            guard let source = calendar.source else { return false }
            return source.sourceType == .calDAV || source.sourceType == .local
        }
        logger.info("其中 \(filteredCalendars.count) 个是可用日历")
        
        return filteredCalendars
    }
    
    public func getTargetCalendar() throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        
        // 首先尝试找到指定名称的日历
        if let calendar = calendars.first(where: { $0.title == config.targetCalendarName }) {
            return calendar
        }
        
        // 如果找不到，尝试创建一个新的日历
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = config.targetCalendarName
        
        // 尝试使用本地日历源
        let sources = eventStore.sources.filter { $0.sourceType == .local }
        if let source = sources.first {
            calendar.source = source
        } else {
            throw CalendarError.noCalendarsAvailable
        }
        
        // 保存日历
        try eventStore.saveCalendar(calendar, commit: true)
        
        return calendar
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    public func getEvents(in calendar: EKCalendar) async throws -> [EKEvent] {
        let predicate = eventStore.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [calendar]
        )
        return eventStore.events(matching: predicate)
    }
} 