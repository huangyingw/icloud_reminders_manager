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
            return source.sourceType == .calDAV &&
                   source.title == "iCloud" &&
                   !calendar.isSubscribed &&
                   calendar.allowsContentModifications
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
    
    public func processTargetCalendarEvents() async throws {
        let targetCalendar = try getTargetCalendar()
        logger.info("\n处理目标日历中的事件...")
        
        // 使用当前时间的前后一年作为范围
        let calendar = Calendar.current
        let oneYearAgo = calendar.date(byAdding: .year, value: -1, to: Date())!
        let oneYearLater = calendar.date(byAdding: .year, value: 1, to: Date())!
        
        let targetPredicate = eventStore.predicateForEvents(withStart: oneYearAgo, end: oneYearLater, calendars: [targetCalendar])
        let targetEvents = eventStore.events(matching: targetPredicate)
        
        logger.info("在目标日历 '\(targetCalendar.title)' 中找到 \(targetEvents.count) 个事件")
        logger.info("搜索范围: \(oneYearAgo) 到 \(oneYearLater)")
        logger.info("日历ID: \(targetCalendar.calendarIdentifier)")
        logger.info("日历类型: \(targetCalendar.type.rawValue)")
        logger.info("日历来源: \(targetCalendar.source?.title ?? "未知")")
        
        // 按标题分组事件，用于处理重复事件
        var eventGroups: [String: [EKEvent]] = [:]
        var emptyEvents: [EKEvent] = []
        
        // 第一遍遍历：分类事件
        for event in targetEvents {
            // 检查是否为空白事件
            if event.title?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                emptyEvents.append(event)
                logger.info("发现空白事件，将被删除")
                continue
            }
            
            // 按标题分组
            let title = event.title ?? ""
            if eventGroups[title] == nil {
                eventGroups[title] = []
            }
            eventGroups[title]?.append(event)
        }
        
        // 删除空白事件
        for event in emptyEvents {
            try eventStore.remove(event, span: .thisEvent)
            logger.info("已删除空白事件")
        }
        
        // 处理重复事件
        for (title, events) in eventGroups {
            if events.count > 1 {
                logger.info("发现标题为 '\(title)' 的重复事件，共 \(events.count) 个")
                
                // 分离循环事件和普通事件
                let recurringEvents = events.filter { $0.recurrenceRules?.isEmpty == false }
                let normalEvents = events.filter { $0.recurrenceRules?.isEmpty ?? true }
                
                // 处理循环事件
                for event in recurringEvents {
                    logger.info("处理循环事件: '\(title)'")
                    if event.startDate < Date() {
                        logger.info("循环事件已过期，准备删除")
                        try eventStore.remove(event, span: .thisEvent)
                        logger.info("已删除过期的循环事件")
                    } else {
                        logger.info("循环事件未过期，保留")
                    }
                }
                
                // 处理普通的重复事件
                if !normalEvents.isEmpty {
                    // 按开始时间排序
                    let sortedEvents = normalEvents.sorted { $0.startDate < $1.startDate }
                    
                    // 保留最新的事件，删除其他事件
                    for event in sortedEvents.dropLast() {
                        try eventStore.remove(event, span: .thisEvent)
                        logger.info("已删除重复事件: '\(title)'")
                    }
                    
                    // 获取保留的事件
                    if let latestEvent = sortedEvents.last {
                        // 如果是过期事件，移动到本周
                        if latestEvent.startDate < Date() {
                            logger.info("保留的事件已过期，准备移动到本周的相同时间")
                            try moveEventToCurrentWeek(latestEvent, targetCalendar: targetCalendar)
                        }
                    }
                }
            } else if let event = events.first {
                // 单个事件的处理
                if event.recurrenceRules?.isEmpty == false {
                    // 单个循环事件
                    logger.info("处理单个循环事件: '\(title)'")
                    if event.startDate < Date() {
                        logger.info("循环事件已过期，准备删除")
                        try eventStore.remove(event, span: .thisEvent)
                        logger.info("已删除过期的循环事件")
                    } else {
                        logger.info("循环事件未过期，保留")
                    }
                } else if event.startDate < Date() {
                    // 单个普通事件
                    logger.info("- 事件已过期，准备移动到本周的相同时间")
                    try moveEventToCurrentWeek(event, targetCalendar: targetCalendar)
                } else {
                    logger.info("- 事件未过期，无需处理")
                }
            }
        }
    }
    
    public func processSourceCalendars() async throws {
        let iCloudCalendars = getICloudCalendars()
        for sourceCalendar in iCloudCalendars {
            if sourceCalendar.title == config.calendar.targetCalendarName {
                continue
            }
            
            logger.info("\n处理日历: \(sourceCalendar.title)")
            
            let predicate = eventStore.predicateForEvents(withStart: Date.distantPast, end: Date.distantFuture, calendars: [sourceCalendar])
            let events = eventStore.events(matching: predicate)
            
            for event in events {
                try await moveEventToTargetCalendar(event)
            }
            
            if isCalendarEmpty(sourceCalendar) {
                try deleteEmptyCalendar(sourceCalendar)
            }
        }
    }
    
    public func cleanupEmptyCalendars() throws {
        let allCalendars = eventStore.calendars(for: .event)
        for calendar in allCalendars {
            if calendar.title == config.calendar.targetCalendarName {
                continue
            }
            
            if isCalendarEmpty(calendar) {
                try deleteEmptyCalendar(calendar)
            }
        }
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
        
        // 调整过期事件的日期到当前这个星期的同一天同一时间
        let (adjustedStartDate, adjustedEndDate) = adjustEventDates(startDate: event.startDate, endDate: event.endDate)
        newEvent.startDate = adjustedStartDate
        newEvent.endDate = adjustedEndDate
        
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
    
    private func adjustEventDates(startDate: Date, endDate: Date) -> (Date, Date) {
        // 创建一个以星期一为开始的日历
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // 2 代表星期一
        
        // 获取事件的星期几、小时和分钟
        let startComponents = calendar.dateComponents([.weekday, .hour, .minute], from: startDate)
        logger.info("原始事件组件:")
        logger.info("- 星期几: \(startComponents.weekday ?? 0)")  // 1=星期日, 2=星期一, ..., 7=星期六
        logger.info("- 小时: \(startComponents.hour ?? 0)")
        logger.info("- 分钟: \(startComponents.minute ?? 0)")
        
        // 获取本周的日期
        var newComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        newComponents.weekday = startComponents.weekday
        newComponents.hour = startComponents.hour
        newComponents.minute = startComponents.minute
        
        logger.info("调整后的组件:")
        logger.info("- 年份周: \(newComponents.yearForWeekOfYear ?? 0)")
        logger.info("- 年内周数: \(newComponents.weekOfYear ?? 0)")
        logger.info("- 星期几: \(newComponents.weekday ?? 0)")  // 1=星期日, 2=星期一, ..., 7=星期六
        logger.info("- 小时: \(newComponents.hour ?? 0)")
        logger.info("- 分钟: \(newComponents.minute ?? 0)")
        
        // 创建新的开始时间
        let newStartDate = calendar.date(from: newComponents)!
        
        // 计算事件持续时间
        let duration = endDate.timeIntervalSince(startDate)
        logger.info("事件持续时间: \(duration) 秒")
        
        // 创建新的结束时间
        let newEndDate = newStartDate.addingTimeInterval(duration)
        
        return (newStartDate, newEndDate)
    }
    
    private func moveEventToCurrentWeek(_ event: EKEvent, targetCalendar: EKCalendar) throws {
        // 创建新事件
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = event.title
        
        // 调整过期事件的日期到当前这个星期的同一天同一时间
        let (adjustedStartDate, adjustedEndDate) = adjustEventDates(startDate: event.startDate, endDate: event.endDate)
        newEvent.startDate = adjustedStartDate
        newEvent.endDate = adjustedEndDate
        
        logger.info("- 调整后的开始时间: \(adjustedStartDate)")
        logger.info("- 调整后的结束时间: \(adjustedEndDate)")
        
        newEvent.calendar = targetCalendar
        
        // 复制其他属性
        newEvent.notes = event.notes
        newEvent.location = event.location
        newEvent.url = event.url
        newEvent.isAllDay = event.isAllDay
        
        // 复制重复规则
        if let rules = event.recurrenceRules {
            newEvent.recurrenceRules = rules
            logger.info("- 复制了重复规则")
        }
        
        // 保存新事件
        try eventStore.save(newEvent, span: .thisEvent)
        logger.info("- 已创建新事件")
        
        // 删除原事件
        try eventStore.remove(event, span: .thisEvent)
        logger.info("- 已删除原事件")
        
        logger.info("已将过期事件 '\(event.title ?? "未命名事件")' 移动到本周的相同时间")
    }
} 