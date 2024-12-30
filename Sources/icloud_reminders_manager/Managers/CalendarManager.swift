import EventKit
import Logging

public class CalendarManager {
    internal let eventStore: EKEventStore
    private let config: Config
    private let logger: Logger
    
    public init(eventStore: EKEventStore, config: Config) {
        self.eventStore = eventStore
        self.config = config
        self.logger = Logger(label: "CalendarManager")
    }
    
    /// 获取源日历
    internal func getSourceCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event).filter { calendar in
            calendar.title != config.personalCalendarName
        }
    }
    
    /// 获取目标日历
    internal func getTargetCalendar() -> EKCalendar? {
        return eventStore.calendars(for: .event).first { calendar in
            calendar.title == config.personalCalendarName
        }
    }
    
    /// 移动事件到目标日历
    internal func moveEventToTargetCalendar(_ event: EKEvent, targetCalendar: EKCalendar) throws {
        // 清除闹钟以避免错误
        event.alarms = nil
        event.calendar = targetCalendar
        try eventStore.save(event, span: .thisEvent)
    }
}

public enum CalendarError: Error {
    case calendarNotFound
    case reminderListNotFound
    case iCloudAccountNotFound
    case operationFailed
    case targetCalendarNotFound
} 