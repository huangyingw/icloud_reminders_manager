import Foundation
import EventKit
import Logging

public class App {
    private let logger: Logging.Logger
    private let eventStore: EKEventStore
    private let config: Config
    private let calendarManager: CalendarManager
    private let reminderManager: ReminderManager
    private let eventMerger: EventMerger
    
    public init(config: Config, logger: Logging.Logger? = nil) {
        self.eventStore = EKEventStore()
        self.config = config
        self.logger = logger ?? Logging.Logger(label: "com.example.icloud_reminders_manager")
        self.calendarManager = CalendarManager(eventStore: eventStore, config: config, logger: self.logger)
        self.reminderManager = ReminderManager(eventStore: eventStore, config: config, logger: self.logger)
        self.eventMerger = EventMerger(eventStore: eventStore, config: config, logger: self.logger)
    }
    
    public func run() async throws {
        try await requestAccess()
        try await processExpiredEvents()
        try await processExpiredReminders()
        try await mergeTargetCalendarEvents()
        logger.info("处理完成")
    }
    
    // 处理过期事件
    public func processExpiredEvents() async throws {
        // 获取所有 iCloud 日历
        let iCloudCalendars = calendarManager.getICloudCalendars()
        logger.info("找到 \(iCloudCalendars.count) 个 iCloud 日历")
        
        // 处理每个日历中的过期事件
        for calendar in iCloudCalendars {
            logger.info("处理日历：\(calendar.title)")
            let events = try await calendarManager.getEvents(in: calendar)
            logger.info("找到 \(events.count) 个事件")
            
            // 将过期事件移动到目标日历
            for event in events {
                if event.startDate < Date() {
                    try await calendarManager.moveEventToTargetCalendar(event)
                }
            }
        }
    }
    
    // 处理过期提醒
    public func processExpiredReminders() async throws {
        let reminders = try await reminderManager.getExpiredReminders()
        logger.info("找到 \(reminders.count) 个过期提醒")
        
        // 将过期提醒转换为事件并保存到目标日历
        for reminder in reminders {
            try await reminderManager.processReminder(reminder)
        }
    }
    
    // 合并目标日历中的重复事件
    public func mergeTargetCalendarEvents() async throws {
        let targetCalendar = try calendarManager.getTargetCalendar()
        let targetEvents = try await calendarManager.getEvents(in: targetCalendar)
        let mergedEvents = try await eventMerger.mergeDuplicateEvents(targetEvents)
        logger.info("合并后剩余 \(mergedEvents.count) 个事件")
    }
    
    private func requestAccess() async throws {
        // 检查日历访问权限
        let eventAuthStatus = EKEventStore.authorizationStatus(for: .event)
        logger.info("日历访问权限状态: \(eventAuthStatus.rawValue)")
        
        // 检查提醒事项访问权限
        let reminderAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
        logger.info("提醒事项访问权限状态: \(reminderAuthStatus.rawValue)")
        
        // 如果没有权限，请求访问
        if eventAuthStatus == .notDetermined {
            logger.info("请求日历访问权限...")
            let eventAccess = try await eventStore.requestAccess(to: .event)
            logger.info("日历访问权限: \(eventAccess)")
        }
        
        if reminderAuthStatus == .notDetermined {
            logger.info("请求提醒事项访问权限...")
            let reminderAccess = try await eventStore.requestAccess(to: .reminder)
            logger.info("提醒事项访问权限: \(reminderAccess)")
        }
        
        // 再次检查权限状态
        let finalEventAuthStatus = EKEventStore.authorizationStatus(for: .event)
        let finalReminderAuthStatus = EKEventStore.authorizationStatus(for: .reminder)
        
        guard finalEventAuthStatus == .authorized && finalReminderAuthStatus == .authorized else {
            logger.error("请在系统设置中授予日历和提醒事项的访问权限")
            logger.error("1. 打开 System Settings（系统设置）")
            logger.error("2. 点击 Privacy & Security（隐私与安全性）")
            logger.error("3. 点击 Calendars（日历）")
            logger.error("4. 找到我们的应用程序并勾选")
            logger.error("5. 点击 Reminders（提醒事项）")
            logger.error("6. 同样找到我们的应用程序并勾选")
            throw CalendarError.accessDenied
        }
        
        logger.info("已获取所有必要的访问权限")
    }
} 