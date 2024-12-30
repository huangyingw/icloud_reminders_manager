import Foundation
import EventKit

public class App {
    private let eventStore: EKEventStore
    private let config: Config
    private let logger: Logger
    private let calendarManager: CalendarAccountManager
    private let reminderManager: ReminderManager
    
    public init(eventStore: EKEventStore, config: Config, logger: Logger) {
        self.eventStore = eventStore
        self.config = config
        self.logger = logger
        self.calendarManager = CalendarAccountManager(eventStore: eventStore, config: config)
        self.reminderManager = ReminderManager(eventStore: eventStore, config: config)
    }
    
    public func run() async throws {
        // 请求日历和提醒事项的访问权限
        if #available(macOS 14.0, *) {
            try await eventStore.requestFullAccessToEvents()
            try await eventStore.requestFullAccessToReminders()
        } else {
            try await eventStore.requestAccess(to: .event)
            try await eventStore.requestAccess(to: .reminder)
        }
        
        // 启用 iCloud 账号
        try calendarManager.enableiCloudAccount()
        
        // 获取已启用的日历和提醒列表
        let enabledCalendars = calendarManager.getEnabledCalendars()
        let enabledReminderLists = calendarManager.getEnabledReminderLists()
        
        logger.log("\n已启用的日历:")
        for calendar in enabledCalendars {
            logger.log("- \(calendar.title)")
        }
        
        logger.log("\n已启用的提醒列表:")
        for list in enabledReminderLists {
            logger.log("- \(list.title)")
        }
        
        // 处理每个提醒列表
        for list in enabledReminderLists {
            logger.log("\n处理提醒列表: \(list.title)")
            
            // 获取所有过期的未完成提醒
            let reminders = try await reminderManager.getExpiredReminders(from: list)
            
            logger.log("发现 \(reminders.count) 个过期的未完成提醒")
            
            // 处理每个过期的提醒
            for reminder in reminders {
                logger.log("\n处理提醒: \(reminder.title ?? "无标题")")
                try await reminderManager.processReminder(reminder)
            }
        }
    }
}

public class ReminderManager {
    private let eventStore: EKEventStore
    private let config: Config
    
    public init(eventStore: EKEventStore, config: Config) {
        self.eventStore = eventStore
        self.config = config
    }
    
    public func getExpiredReminders(from list: EKCalendar) async throws -> [EKReminder] {
        // 获取所有未完成的提醒
        let predicate = eventStore.predicateForIncompleteReminders(
            withDueDateStarting: nil,
            ending: Date(),
            calendars: [list]
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            eventStore.fetchReminders(matching: predicate) { reminders in
                if let reminders = reminders {
                    // 过滤掉空标题的提醒
                    let validReminders = reminders.filter { $0.title?.isEmpty == false }
                    continuation.resume(returning: validReminders)
                } else {
                    continuation.resume(throwing: AppError.noRemindersAvailable)
                }
            }
        }
    }
    
    public func processReminder(_ reminder: EKReminder) async throws {
        // 如果标题为空，直接删除提醒
        if reminder.title?.isEmpty != false {
            reminder.isCompleted = true
            try eventStore.save(reminder, commit: true)
            return
        }
        
        // 获取目标日历
        guard let targetCalendar = eventStore.calendars(for: .event).first(where: { $0.title == config.calendars.target }) else {
            throw AppError.noCalendarsAvailable
        }
        
        // 创建新事件
        let event = EKEvent(eventStore: eventStore)
        event.title = reminder.title
        event.notes = reminder.notes
        event.calendar = targetCalendar
        
        // 设置事件时间
        if let dueDate = reminder.dueDateComponents?.date {
            event.startDate = dueDate
            event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: dueDate) ?? dueDate
        }
        
        // 保存事件
        try eventStore.save(event, span: .thisEvent)
        
        // 标记提醒为已完成
        reminder.isCompleted = true
        try eventStore.save(reminder, commit: true)
    }
} 