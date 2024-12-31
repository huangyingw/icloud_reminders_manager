import EventKit
import Logging

public class ReminderManager {
    internal let eventStore: EKEventStore
    internal let config: Config
    internal let logger: Logger
    
    public init(eventStore: EKEventStore, config: Config, logger: Logger) {
        self.eventStore = eventStore
        self.config = config
        self.logger = logger
    }
    
    public func getExpiredReminders(from calendar: EKCalendar) async throws -> [EKReminder] {
        let predicate = eventStore.predicateForReminders(in: [calendar])
        let reminders = try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    continuation.resume(returning: reminders)
                } else {
                    continuation.resume(throwing: CalendarError.noRemindersFound)
                }
            }
        }
        
        logger.info("从日历 \(calendar.title) 获取到 \(reminders.count) 个提醒")
        
        let expiredReminders = reminders.filter { reminder in
            // 记录每个提醒的状态
            logger.info("检查提醒: \(reminder.title ?? "无标题")")
            logger.info("- 完成状态: \(reminder.isCompleted)")
            if let dueDate = reminder.dueDateComponents?.date {
                logger.info("- 截止日期: \(dueDate)")
            } else {
                logger.info("- 无截止日期")
            }
            
            // 如果提醒已完成，则跳过
            if reminder.isCompleted {
                logger.info("- 已跳过（已完成）")
                return false
            }
            
            // 如果提醒没有标题，仍然处理它
            if reminder.title?.isEmpty ?? true {
                logger.info("- 无标题提醒")
            }
            
            // 如果提醒有截止日期且已过期，或者没有截止日期，都进行处理
            if let dueDate = reminder.dueDateComponents?.date {
                let isExpired = dueDate < Date()
                logger.info("- 是否过期: \(isExpired)")
                return isExpired
            } else {
                logger.info("- 无截止日期，将被处理")
                return true
            }
        }
        
        logger.info("找到 \(expiredReminders.count) 个需要处理的提醒")
        return expiredReminders
    }
    
    public func getExpiredReminders() async throws -> [EKReminder] {
        // 获取所有提醒事项日历
        let reminderCalendars = eventStore.calendars(for: .reminder)
        logger.info("找到 \(reminderCalendars.count) 个提醒事项日历")
        
        var allExpiredReminders: [EKReminder] = []
        
        // 从每个日历中获取过期提醒
        for calendar in reminderCalendars {
            logger.info("正在处理日历: \(calendar.title)")
            let reminders = try await getExpiredReminders(from: calendar)
            allExpiredReminders.append(contentsOf: reminders)
        }
        
        logger.info("总共找到 \(allExpiredReminders.count) 个需要处理的提醒")
        return allExpiredReminders
    }
    
    public func processReminder(_ reminder: EKReminder) async throws {
        guard let title = reminder.title, !title.isEmpty else {
            reminder.isCompleted = true
            try eventStore.save(reminder, commit: true)
            return
        }
        
        // 获取目标日历
        guard let targetCalendar = eventStore.calendars(for: .event).first(where: { $0.title == config.targetCalendarName }) else {
            throw CalendarError.noCalendarsAvailable
        }
        
        // 创建事件
        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.notes = reminder.notes
        event.calendar = targetCalendar
        
        // 设置时间
        if let dueDate = reminder.dueDateComponents?.date {
            event.startDate = dueDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate)!
        } else {
            let now = Date()
            event.startDate = now
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        }
        
        // 保存事件
        try eventStore.save(event, span: .thisEvent)
        
        // 标记提醒为已完成
        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)
    }
} 