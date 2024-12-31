import XCTest
import EventKit
@testable import Core

class EventMergerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: Core.Logger!
    var eventMerger: EventMerger!
    var iCloudSource: EKSource!
    var calendar: EKCalendar!
    
    override func setUp() {
        super.setUp()
        
        eventStore = MockEventStore()
        config = Config(targetCalendarName: "个人")
        logger = Core.Logger()
        
        // 创建模拟的 iCloud 源
        iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建测试日历
        calendar = eventStore.createMockCalendar(title: "测试日历")
        calendar.source = iCloudSource
        
        eventMerger = EventMerger(eventStore: eventStore, config: config, logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        logger = nil
        eventMerger = nil
        iCloudSource = nil
        calendar = nil
        super.tearDown()
    }
    
    func testMergeEvents() async throws {
        // 创建重复事件
        let startDate = Date()
        let event1 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        let event2 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        let event3 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        
        // 合并重复事件
        try await eventMerger.mergeEvents([event1, event2, event3])
        
        // 验证结果
        XCTAssertEqual(eventStore.mockEvents.count, 1)
        XCTAssertTrue(eventStore.mockEvents.contains { $0.title == "重复事件" })
    }
    
    func testMergeEventsWithDifferentTitles() async throws {
        // 创建不同标题的事件
        let startDate = Date()
        let event1 = eventStore.createMockEvent(title: "事件1", startDate: startDate, calendar: calendar)
        let event2 = eventStore.createMockEvent(title: "事件2", startDate: startDate, calendar: calendar)
        
        // 合并事件
        try await eventMerger.mergeEvents([event1, event2])
        
        // 验证结果 - 不同标题的事件不应该被合并
        XCTAssertEqual(eventStore.mockEvents.count, 2)
        XCTAssertTrue(eventStore.mockEvents.contains { $0.title == "事件1" })
        XCTAssertTrue(eventStore.mockEvents.contains { $0.title == "事件2" })
    }
} 