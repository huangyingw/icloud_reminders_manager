import EventKit
import Foundation

public class RemindersManager {
    private let config: Config
    private let eventStore: EKEventStore
    private let logger: FileLogger
    
    public init(config: Config, eventStore: EKEventStore, logger: FileLogger) {
        self.config = config
        self.eventStore = eventStore
        self.logger = logger
    }
    
    public func run() async throws {
        // 获取所有提醒事项日历
        let reminderCalendars = eventStore.calendars(for: .reminder)
        
        // 过滤出目标提醒事项列表
        let targetCalendars = reminderCalendars.filter { calendar in
            config.reminder.listNames.contains(calendar.title)
        }
        
        // 获取所有过期提醒
        let predicate = eventStore.predicateForReminders(in: targetCalendars)
        var reminders: [EKReminder] = []
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            eventStore.fetchReminders(matching: predicate) { fetchedReminders in
                if let fetchedReminders = fetchedReminders {
                    reminders = fetchedReminders
                }
                continuation.resume()
            }
        }
        
        // 获取目标日历
        let targetCalendar = try getTargetCalendar()
        
        // 处理每个过期提醒
        for reminder in reminders {
            if let dueDate = reminder.dueDateComponents?.date, dueDate < Date() {
                try await processReminder(reminder, targetCalendar: targetCalendar)
            }
        }
    }
    
    private func getTargetCalendar() throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        guard let targetCalendar = calendars.first(where: { $0.title == config.calendar.targetCalendarName }) else {
            throw CalendarError.targetCalendarNotFound
        }
        return targetCalendar
    }
    
    private func processReminder(_ reminder: EKReminder, targetCalendar: EKCalendar) async throws {
        // 创建新事件
        let event = EKEvent(eventStore: eventStore)
        event.title = reminder.title ?? "未命名提醒"
        
        // 设置事件时间
        if let dueDate = reminder.dueDateComponents?.date {
            event.startDate = dueDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate)!
        }
        
        // 设置其他属性
        event.notes = reminder.notes
        event.calendar = targetCalendar
        
        // 保存事件
        try eventStore.save(event, span: .thisEvent)
        
        // 删除提醒
        try eventStore.remove(reminder, commit: true)
        
        logger.info("已将提醒 '\(reminder.title ?? "未命名提醒")' 转换为事件并移动到 '\(targetCalendar.title)'")
    }
} 