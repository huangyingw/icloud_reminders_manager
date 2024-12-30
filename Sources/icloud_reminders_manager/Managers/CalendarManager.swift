import Foundation
import EventKit

public class CalendarManager {
    private let eventStore: EKEventStore
    private let config: Config
    
    public init(eventStore: EKEventStore, config: Config) {
        self.eventStore = eventStore
        self.config = config
    }
    
    /// 获取源日历
    public func getSourceCalendars() -> [EKCalendar] {
        let calendars = eventStore.calendars(for: .event)
        return calendars.filter { calendar in
            config.calendar.sourceCalendarNames.contains(calendar.title)
        }
    }
    
    /// 获取目标日历
    public func getTargetCalendar() -> EKCalendar? {
        let calendars = eventStore.calendars(for: .event)
        return calendars.first { calendar in
            calendar.title == config.calendar.targetCalendarName
        }
    }
    
    /// 将事件移动到目标日历
    public func moveEventToTargetCalendar(_ event: EKEvent, targetCalendar: EKCalendar) throws {
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