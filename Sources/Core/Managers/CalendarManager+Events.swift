import EventKit
import Logging

extension CalendarManager {
    /// 移动事件到个人日历
    public func moveEventsToPersonalCalendar() async throws {
        logger.info("\n开始移动事件...")
        
        // 获取源日历
        let sourceCalendars = getICloudCalendars()
        logger.info("发现 \(sourceCalendars.count) 个源日历")
        
        // 获取目标日历
        let targetCalendar = try getTargetCalendar()
        logger.info("目标日历: \(targetCalendar.title)")
        
        // 获取本周的开始时间
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        logger.info("本周开始时间: \(formatDate(weekStart))")
        
        // 获取所有事件
        var allEvents: [EKEvent] = []
        for sourceCalendar in sourceCalendars {
            let predicate = eventStore.predicateForEvents(withStart: weekStart, end: Date.distantFuture, calendars: [sourceCalendar])
            let events = eventStore.events(matching: predicate)
            let validEvents = events.filter { event in
                // 过滤掉没有标题的事件
                guard let title = event.title, !title.isEmpty else { return false }
                return true
            }
            allEvents.append(contentsOf: validEvents)
        }
        logger.info("发现 \(allEvents.count) 个有效事件")
        
        // 按标题分组所有事件
        let eventsByTitle = Dictionary(grouping: allEvents) { $0.title ?? "" }
        
        // 处理每组事件
        for (title, events) in eventsByTitle {
            logger.info("\n处理事件组: \(title)")
            logger.info("- 该组共有 \(events.count) 个事件")
            
            try await processEventGroup(events, targetCalendar: targetCalendar, weekStart: weekStart)
        }
        
        logger.info("\n事件移动完成")
    }
    
    /// 移动单个事件到目标日历
    public func moveEventToTargetCalendar(_ event: EKEvent) async throws {
        // 获取目标日历
        let targetCalendar = try getTargetCalendar()
        
        // 如果事件已经在目标日历中，直接返回
        if event.calendar == targetCalendar {
            return
        }
        
        // 如果是循环事件，使用特殊处理
        if event.hasRecurrenceRules {
            try await processRecurringEvents([event], targetCalendar: targetCalendar)
            return
        }
        
        // 创建新事件
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = event.title
        newEvent.notes = event.notes
        newEvent.calendar = targetCalendar
        newEvent.startDate = event.startDate
        newEvent.endDate = event.endDate
        newEvent.isAllDay = event.isAllDay
        newEvent.availability = event.availability
        newEvent.location = event.location
        newEvent.url = event.url
        
        // 保存新事件
        try await eventStore.save(newEvent, span: .thisEvent)
        
        // 删除原事件
        try await eventStore.remove(event, span: .thisEvent)
    }
    
    /// 处理事件组
    private func processEventGroup(_ events: [EKEvent], targetCalendar: EKCalendar, weekStart: Date) async throws {
        // 按开始时间排序
        let sortedEvents = events.sorted { $0.startDate > $1.startDate }
        
        // 获取最新的事件
        let latestEvent = sortedEvents[0]
        
        // 如果是循环事件，单独处理
        if latestEvent.hasRecurrenceRules {
            try await processRecurringEvents(events, targetCalendar: targetCalendar)
            return
        }
        
        // 创建新事件
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = latestEvent.title
        newEvent.notes = latestEvent.notes
        newEvent.calendar = targetCalendar
        
        // 如果事件已过期，移动到下周日
        if latestEvent.startDate < weekStart {
            let nextSunday = Calendar.current.nextDate(after: weekStart,
                                                     matching: DateComponents(weekday: 1),
                                                     matchingPolicy: .nextTime)!
            newEvent.startDate = nextSunday
            newEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: nextSunday)!
        } else {
            newEvent.startDate = latestEvent.startDate
            newEvent.endDate = latestEvent.endDate
        }
        
        try await eventStore.save(newEvent, span: EKSpan.thisEvent)
        logger.info("- 已移动事件: \(formatDate(newEvent.startDate))")
        
        // 删除所有原始事件
        for event in events {
            try await eventStore.remove(event, span: EKSpan.thisEvent)
            logger.info("- 已删除原事件: \(formatDate(event.startDate))")
        }
    }
    
    /// 处理循环事件
    private func processRecurringEvents(_ events: [EKEvent], targetCalendar: EKCalendar) async throws {
        // 按开始时间排序
        let sortedEvents = events.sorted { $0.startDate > $1.startDate }
        let latestEvent = sortedEvents[0]
        
        // 移动到目标日历
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = latestEvent.title
        newEvent.notes = latestEvent.notes
        newEvent.calendar = targetCalendar
        newEvent.startDate = latestEvent.startDate
        newEvent.endDate = latestEvent.endDate
        
        // 复制循环规则
        if let rules = latestEvent.recurrenceRules {
            newEvent.recurrenceRules = rules
        }
        
        try await eventStore.save(newEvent, span: EKSpan.futureEvents)
        logger.info("- 已移动循环事件")
        
        // 删除所有原始循环事件
        for event in events {
            try await eventStore.remove(event, span: EKSpan.futureEvents)
            logger.info("- 已删除原循环事件")
        }
    }
    
    /// 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
    
    /// 将事件移动到当前周
    public func moveEventToCurrentWeek(_ event: EKEvent) async throws {
        // 获取目标日历
        let targetCalendar = try getTargetCalendar()
        
        // 计算当前周的开始和结束时间
        let calendar = Calendar.current
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let currentWeekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        
        // 如果事件已经在当前周，只需要移动到目标日历
        if event.startDate >= currentWeekStart && event.startDate < currentWeekEnd {
            if event.calendar != targetCalendar {
                try await moveEventToTargetCalendar(event)
            }
            return
        }
        
        // 计算事件在当前周的偏移量
        let weekday = calendar.component(.weekday, from: event.startDate)
        let targetWeekday = calendar.component(.weekday, from: Date())
        let dayOffset = targetWeekday - weekday
        
        // 计算新的开始和结束时间
        let newStartDate = calendar.date(byAdding: .day, value: dayOffset, to: currentWeekStart)!
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let newEndDate = newStartDate.addingTimeInterval(duration)
        
        // 更新事件时间
        event.startDate = newStartDate
        event.endDate = newEndDate
        
        // 移动到目标日历
        if event.calendar != targetCalendar {
            event.calendar = targetCalendar
        }
        
        // 保存更改
        try await eventStore.save(event, span: .thisEvent)
    }
} 