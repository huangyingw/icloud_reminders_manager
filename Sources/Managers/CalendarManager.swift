import Foundation
import EventKit

public class CalendarManager {
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    public func moveExpiredEventToCurrentWeek(_ event: EKEvent) async throws {
        let calendar = Calendar.current
        let now = Date()
        
        // 获取事件的原始星期几
        let originalWeekday = calendar.component(.weekday, from: event.startDate)
        
        // 获取当前日期所在周的开始日期
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        
        // 计算目标日期：当前周的相同星期几
        let targetDate = calendar.date(byAdding: .day, value: originalWeekday - 1, to: currentWeekStart)!
        
        // 保持原始时间部分
        let originalHour = calendar.component(.hour, from: event.startDate)
        let originalMinute = calendar.component(.minute, from: event.startDate)
        
        // 创建新的日期
        var components = calendar.dateComponents([.year, .month, .day], from: targetDate)
        components.hour = originalHour
        components.minute = originalMinute
        
        let newStartDate = calendar.date(from: components)!
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let newEndDate = newStartDate.addingTimeInterval(duration)
        
        // 更新事件日期
        event.startDate = newStartDate
        event.endDate = newEndDate
        
        try eventStore.save(event, span: .thisEvent, commit: true)
    }
    
    public func deleteExpiredRecurringEvents() async throws {
        let now = Date()
        let predicate = eventStore.predicateForEvents(withStart: Date.distantPast, end: now, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        for event in events {
            guard let rules = event.recurrenceRules, !rules.isEmpty else { continue }
            
            // 检查是否所有规则都已过期
            let allRulesExpired = rules.allSatisfy { rule in
                guard let endDate = rule.recurrenceEnd?.endDate else { return false }
                return endDate < now
            }
            
            if allRulesExpired {
                try eventStore.remove(event, span: .futureEvents, commit: true)
            }
        }
    }
} 