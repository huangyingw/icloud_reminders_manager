import XCTest
import EventKit
@testable import Core

final class EventMergerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: FileLogger!
    var eventMerger: EventMerger!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        config = Config(
            calendar: CalendarConfig(targetCalendarName: "个人"),
            reminder: ReminderConfig(listNames: ["提醒事项"])
        )
        logger = FileLogger(label: "test.logger")
        
        // 创建 iCloud 源
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建日历
        let calendar = eventStore.createMockCalendar(title: "测试日历", type: .event)
        calendar.setValue(iCloudSource, forKey: "source")
        
        eventMerger = EventMerger(logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        logger = nil
        eventMerger = nil
        super.tearDown()
    }
    
    func testMergeDuplicateEvents() async throws {
        // 创建重复事件
        let calendar = eventStore.createMockCalendar(title: "测试日历", type: .event)
        let startDate = Date()
        
        let event1 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        let event2 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        let event3 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        
        // 合并重复事件
        let mergedEvents = try await eventMerger.mergeDuplicateEvents([event1, event2, event3])
        
        // 验证结果
        XCTAssertEqual(mergedEvents.count, 1, "应该只剩下一个事件")
        XCTAssertEqual(mergedEvents[0].title, "重复事件", "事件标题应该保持不变")
    }
    
    func testMergeDifferentEvents() async throws {
        // 创建不同标题的事件
        let calendar = eventStore.createMockCalendar(title: "测试日历", type: .event)
        let startDate = Date()
        
        let event1 = eventStore.createMockEvent(title: "事件1", startDate: startDate, calendar: calendar)
        let event2 = eventStore.createMockEvent(title: "事件2", startDate: startDate, calendar: calendar)
        
        // 合并事件
        let mergedEvents = try await eventMerger.mergeDuplicateEvents([event1, event2])
        
        // 验证结果 - 不同标题的事件不应该被合并
        XCTAssertEqual(mergedEvents.count, 2, "不同标题的事件不应该被合并")
        XCTAssertTrue(mergedEvents.contains { $0.title == "事件1" })
        XCTAssertTrue(mergedEvents.contains { $0.title == "事件2" })
    }
} 