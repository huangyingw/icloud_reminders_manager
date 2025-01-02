import EventKit
import Foundation
import Logging

public class App {
    private let config: Config
    private let eventStore: EKEventStore
    private let logger: FileLogger
    private let calendarManager: CalendarManager
    private let remindersManager: RemindersManager
    private let eventMerger: EventMerger
    
    public init(config: Config, eventStore: EKEventStore, logger: FileLogger) {
        self.config = config
        self.eventStore = eventStore
        self.logger = logger
        self.calendarManager = CalendarManager(config: config, eventStore: eventStore, logger: logger)
        self.remindersManager = RemindersManager(config: config, eventStore: eventStore, logger: logger)
        self.eventMerger = EventMerger(logger: logger)
    }
    
    public func run() async throws {
        logger.info("\n开始处理...")
        
        // 获取所有 iCloud 日历
        let iCloudCalendars = calendarManager.getICloudCalendars()
        logger.info("找到 \(iCloudCalendars.count) 个 iCloud 日历:")
        for calendar in iCloudCalendars {
            logger.info("- \(calendar.title)")
        }
        
        // 获取目标日历
        let targetCalendar = try calendarManager.getTargetCalendar()
        logger.info("\n目标日历: \(targetCalendar.title)")
        
        // 处理每个源日历中的事件
        for sourceCalendar in iCloudCalendars {
            // 跳过目标日历
            if sourceCalendar.title == config.calendar.targetCalendarName {
                continue
            }
            
            logger.info("\n处理日历: \(sourceCalendar.title)")
            
            // 获取所有事件
            let predicate = eventStore.predicateForEvents(withStart: Date.distantPast, end: Date.distantFuture, calendars: [sourceCalendar])
            let events = eventStore.events(matching: predicate)
            
            // 移动事件到目标日历
            for event in events {
                try await calendarManager.moveEventToTargetCalendar(event)
            }
            
            // 如果日历为空，删除它
            if calendarManager.isCalendarEmpty(sourceCalendar) {
                try calendarManager.deleteEmptyCalendar(sourceCalendar)
            }
        }
        
        // 处理提醒事项
        try await remindersManager.run()
        
        logger.info("\n处理完成")
    }
} 