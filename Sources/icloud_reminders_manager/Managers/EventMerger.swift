import EventKit

public class EventMerger {
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    /// 合并事件
    public func mergeEvents(_ events: [EKEvent], into targetCalendar: EKCalendar) throws -> EKEvent {
        guard let latestEvent = events.max(by: { $0.startDate < $1.startDate }) else {
            throw CalendarError.operationFailed
        }
        
        // 清除闹钟以避免错误
        latestEvent.alarms = nil
        latestEvent.calendar = targetCalendar
        try eventStore.save(latestEvent, span: .futureEvents)
        
        // 删除其他事件
        for event in events where event !== latestEvent {
            event.alarms = nil
            try eventStore.remove(event, span: .futureEvents)
        }
        
        return latestEvent
    }
} 