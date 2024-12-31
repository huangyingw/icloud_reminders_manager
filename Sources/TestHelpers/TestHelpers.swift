import Foundation
import EventKit

public struct TestHelpers {
    public static func createTestCalendar(name: String) -> EKCalendar {
        let eventStore = EKEventStore()
        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = name
        
        // 创建一个 CalDAV 源
        let source = eventStore.sources.first { source in
            source.sourceType == .calDAV && source.title == "iCloud"
        }
        
        // 如果找不到 iCloud 源，创建一个模拟的源
        if let source = source {
            calendar.source = source
        } else {
            // 在测试环境中，我们可能无法创建真实的 CalDAV 源
            // 这里我们只是记录一个警告
            print("警告: 无法找到 iCloud 源，测试可能会失败")
        }
        
        return calendar
    }
} 