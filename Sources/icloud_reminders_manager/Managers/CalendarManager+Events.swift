import EventKit
import Foundation

extension CalendarManager {
    /// 移动事件到个人日历
    public func moveEventsToPersonalCalendar() async throws {
        logger.info("\n开始移动事件...")
        
        // 获取源日历
        let sourceCalendars = getSourceCalendars()
        logger.info("发现 \(sourceCalendars.count) 个源日历")
        
        // 获取目标日历
        guard let targetCalendar = getTargetCalendar() else {
            throw CalendarError.targetCalendarNotFound
        }
        logger.info("目标日历: \(targetCalendar.title)")
        
        // 获取本周的开始时间
        let calendar = Calendar.current
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        logger.info("本周开始时间: \(formatDate(weekStart))")
        
        // 获取所有事件
        var allEvents: [EKEvent] = []
        for calendar in sourceCalendars {
            let predicate = eventStore.predicateForEvents(withStart: Date.distantPast,
                                                        end: Date.distantFuture,
                                                        calendars: [calendar])
            let events = eventStore.events(matching: predicate)
            // 过滤掉空标题的事件
            let validEvents = events.filter { $0.title?.isEmpty == false }
            allEvents.append(contentsOf: validEvents)
        }
        logger.info("发现 \(allEvents.count) 个有效事件")
        
        // 按标题分组所有事件
        var eventsByTitle = [String: [EKEvent]]()
        for event in allEvents {
            guard let title = event.title else { continue }
            var events = eventsByTitle[title] ?? []
            events.append(event)
            eventsByTitle[title] = events
        }
        
        // 处理每组事件
        for (title, events) in eventsByTitle {
            logger.info("\n处理事件组: \(title)")
            logger.info("- 该组共有 \(events.count) 个事件")
            
            try await processEventGroup(events, targetCalendar: targetCalendar, weekStart: weekStart)
        }
        
        logger.info("\n事件移动完成")
    }
    
    private func processEventGroup(_ events: [EKEvent], targetCalendar: EKCalendar, weekStart: Date) async throws {
        // 获取非循环事件
        let nonRecurringEvents = events.filter { $0.recurrenceRules?.isEmpty != false }
        
        // 如果有非循环事件，处理它们
        if !nonRecurringEvents.isEmpty {
            try await processNonRecurringEvents(nonRecurringEvents, targetCalendar: targetCalendar, weekStart: weekStart)
        }
        
        // 处理循环事件
        let recurringEvents = events.filter { $0.recurrenceRules?.isEmpty == false }
        if !recurringEvents.isEmpty {
            try await processRecurringEvents(recurringEvents, targetCalendar: targetCalendar)
        }
    }
    
    private func processNonRecurringEvents(_ events: [EKEvent], targetCalendar: EKCalendar, weekStart: Date) async throws {
        // 找出最新的事件
        guard let latestEvent = events.max(by: { $0.startDate < $1.startDate }) else {
            return
        }
        
        // 创建新事件
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = latestEvent.title
        newEvent.notes = latestEvent.notes
        newEvent.calendar = targetCalendar
        
        // 如果事件已过期，移动到本周对应时间
        if latestEvent.startDate < weekStart {
            let calendar = Calendar.current
            let originalWeekday = calendar.component(.weekday, from: latestEvent.startDate)
            let originalHour = calendar.component(.hour, from: latestEvent.startDate)
            let originalMinute = calendar.component(.minute, from: latestEvent.startDate)
            
            var newStartComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
            newStartComponents.weekday = originalWeekday
            newStartComponents.hour = originalHour
            newStartComponents.minute = originalMinute
            
            if let newStartDate = calendar.date(from: newStartComponents) {
                newEvent.startDate = newStartDate
                newEvent.endDate = newStartDate.addingTimeInterval(latestEvent.endDate.timeIntervalSince(latestEvent.startDate))
            }
        } else {
            // 如果事件未过期，保持原始时间
            newEvent.startDate = latestEvent.startDate
            newEvent.endDate = latestEvent.endDate
        }
        
        // 复制提醒设置
        if let alarms = latestEvent.alarms {
            newEvent.alarms = alarms
        }
        
        try eventStore.save(newEvent, span: EKSpan.thisEvent)
        logger.info("- 已移动事件: \(formatDate(newEvent.startDate))")
        
        // 删除所有原始事件
        for event in events {
            try eventStore.remove(event, span: EKSpan.thisEvent)
            logger.info("- 已删除原事件: \(formatDate(event.startDate))")
        }
    }
    
    private func processRecurringEvents(_ events: [EKEvent], targetCalendar: EKCalendar) async throws {
        // 只保留最新的循环事件
        guard let latestEvent = events.max(by: { $0.startDate < $1.startDate }) else {
            return
        }
        
        // 移动到目标日历
        let newEvent = EKEvent(eventStore: eventStore)
        newEvent.title = latestEvent.title
        newEvent.notes = latestEvent.notes
        newEvent.calendar = targetCalendar
        newEvent.startDate = latestEvent.startDate
        newEvent.endDate = latestEvent.endDate
        newEvent.recurrenceRules = latestEvent.recurrenceRules
        
        // 复制提醒设置
        if let alarms = latestEvent.alarms {
            newEvent.alarms = alarms
        }
        
        try eventStore.save(newEvent, span: EKSpan.futureEvents)
        logger.info("- 已移动循环事件")
        
        // 删除所有原始循环事件
        for event in events {
            try eventStore.remove(event, span: EKSpan.futureEvents)
            logger.info("- 已删除原循环事件")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
} 