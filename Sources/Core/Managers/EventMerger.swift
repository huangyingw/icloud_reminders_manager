import EventKit
import Logging

public class EventMerger {
    private let logger: FileLogger
    
    public init(logger: FileLogger) {
        self.logger = logger
    }
    
    public func mergeDuplicateEvents(_ events: [EKEvent]) async throws -> [EKEvent] {
        // 按标题分组
        let eventsByTitle = Dictionary(grouping: events) { $0.title ?? "" }
        
        // 存储合并后的事件
        var mergedEvents: [EKEvent] = []
        
        // 处理每组事件
        for (title, events) in eventsByTitle {
            // 跳过空标题的事件
            if title.isEmpty {
                continue
            }
            
            // 如果只有一个事件，直接添加
            if events.count == 1 {
                mergedEvents.append(events[0])
                continue
            }
            
            // 找到最新的事件
            if let latestEvent = events.max(by: { $0.startDate < $1.startDate }) {
                mergedEvents.append(latestEvent)
            }
        }
        
        return mergedEvents
    }
} 