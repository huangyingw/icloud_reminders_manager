import EventKit
import Foundation
import Logging

public class App {
    private let config: Config
    private let eventStore: EKEventStore
    private let logger: FileLogger
    private let calendarManager: CalendarManager
    private let remindersManager: RemindersManager
    
    public init(config: Config, eventStore: EKEventStore, logger: FileLogger) {
        self.config = config
        self.eventStore = eventStore
        self.logger = logger
        self.calendarManager = CalendarManager(config: config, eventStore: eventStore, logger: logger)
        self.remindersManager = RemindersManager(config: config, eventStore: eventStore, logger: logger)
    }
    
    public func run() async throws {
        logger.info("\n开始处理...")
        
        // 获取所有 iCloud 日历
        let iCloudCalendars = calendarManager.getICloudCalendars()
        logger.info("找到 \(iCloudCalendars.count) 个 iCloud 日历:")
        for calendar in iCloudCalendars {
            logger.info("- \(calendar.title)")
        }
        
        // 处理目标日历中的事件
        logger.info("\n处理目标日历中的事件...")
        try await calendarManager.processTargetCalendarEvents()
        
        // 处理其他日历中的事件
        try await calendarManager.processSourceCalendars()
        
        // 处理过期提醒
        try await remindersManager.processExpiredReminders()
        
        logger.info("\n处理完成")
    }
    
    private func getTargetCalendar() throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        guard let targetCalendar = calendars.first(where: { $0.title == config.calendar.targetCalendarName }) else {
            throw CalendarError.targetCalendarNotFound
        }
        return targetCalendar
    }
} 