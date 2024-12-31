import EventKit
import Logging

public class EventMerger {
    private let eventStore: EKEventStore
    private let config: Config
    private let logger: Logger
    
    public init(eventStore: EKEventStore, config: Config, logger: Logger) {
        self.eventStore = eventStore
        self.config = config
        self.logger = logger
    }
    
    public func findDuplicateEvents(_ events: [EKEvent]) -> [[EKEvent]] {
        var duplicateGroups: [[EKEvent]] = []
        var processedEvents = Set<EKEvent>()
        
        for event in events {
            if processedEvents.contains(event) {
                continue
            }
            
            let duplicates = events.filter { other in
                !processedEvents.contains(other) &&
                other.title == event.title &&
                Calendar.current.isDate(other.startDate, inSameDayAs: event.startDate) &&
                other !== event
            }
            
            if !duplicates.isEmpty {
                let group = [event] + duplicates
                duplicateGroups.append(group)
                processedEvents.formUnion(group)
            } else {
                processedEvents.insert(event)
            }
        }
        
        return duplicateGroups
    }
    
    public func mergeEvents(_ events: [EKEvent]) async throws -> [EKEvent] {
        var result = [EKEvent]()
        
        // 按标题分组
        let groupedEvents = Dictionary(grouping: events) { $0.title ?? "" }
        
        // 处理每个组
        for (_, events) in groupedEvents {
            guard !events.isEmpty else { continue }
            
            // 如果只有一个事件，直接添加到结果中
            if events.count == 1 {
                result.append(events[0])
                continue
            }
            
            // 找出主要事件和重复事件
            let sortedEvents = events.sorted { $0.startDate < $1.startDate }
            let primary = sortedEvents[0]
            let duplicates = Array(sortedEvents.dropFirst())
            
            // 合并事件
            let merged = mergeEvents(primary, duplicates: duplicates)
            
            // 保存合并后的事件
            try eventStore.save(merged, span: .thisEvent)
            
            // 删除重复事件
            for duplicate in duplicates {
                try eventStore.remove(duplicate, span: .thisEvent)
            }
            
            result.append(merged)
        }
        
        return result
    }
    
    private func mergeEvents(_ primary: EKEvent, duplicates: [EKEvent]) -> EKEvent {
        // 合并备注
        var notes = [String]()
        if let primaryNotes = primary.notes {
            notes.append(primaryNotes)
        }
        
        for duplicate in duplicates {
            if let duplicateNotes = duplicate.notes {
                notes.append(duplicateNotes)
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            notes.append("原始时间: \(dateFormatter.string(from: duplicate.startDate))")
        }
        
        if !notes.isEmpty {
            primary.notes = notes.joined(separator: "\n\n")
        }
        
        // 复制其他属性（如果有需要）
        if primary.location == nil {
            for duplicate in duplicates {
                if let location = duplicate.location {
                    primary.location = location
                    break
                }
            }
        }
        
        if primary.url == nil {
            for duplicate in duplicates {
                if let url = duplicate.url {
                    primary.url = url
                    break
                }
            }
        }
        
        // 将事件移动到目标日历
        let calendars = eventStore.calendars(for: .event)
        if let targetCalendar = calendars.first(where: { $0.title == config.targetCalendarName }) {
            primary.calendar = targetCalendar
        }
        
        return primary
    }
    
    public func mergeDuplicateEvents(_ events: [EKEvent]) async throws -> [EKEvent] {
        // 按标题分组
        let groupedEvents = Dictionary(grouping: events) { $0.title ?? "" }
        var result: [EKEvent] = []
        
        // 处理每组事件
        for (_, eventsWithSameTitle) in groupedEvents {
            // 如果只有一个事件，保留它
            if eventsWithSameTitle.count == 1 {
                result.append(eventsWithSameTitle[0])
                continue
            }
            
            // 合并事件
            let mergedEvents = try await mergeEvents(eventsWithSameTitle)
            result.append(contentsOf: mergedEvents)
        }
        
        return result
    }
} 