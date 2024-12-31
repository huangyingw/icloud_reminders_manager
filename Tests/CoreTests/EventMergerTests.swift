import XCTest
import EventKit
import Logging
@testable import Core

final class EventMergerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var eventMerger: EventMerger!
    var logger: Logger!
    var testCalendar: EKCalendar!
    var targetCalendar: EKCalendar!
    
    override func setUp() async throws {
        try await super.setUp()
        eventStore = MockEventStore()
        config = Config(targetCalendarName: "个人日历")
        logger = Logger(label: "test")
        eventMerger = EventMerger(eventStore: eventStore, config: config, logger: logger)
        
        // 创建一个本地日历源
        let source = MockSource()
        source.setTitle("本地")
        source.setSourceType(.local)
        eventStore.addMockSource(source)
        
        // 创建测试日历
        testCalendar = EKCalendar(for: .event, eventStore: eventStore)
        testCalendar.title = "测试日历"
        testCalendar.source = source
        eventStore.addMockCalendar(testCalendar)
        
        // 创建目标日历
        targetCalendar = EKCalendar(for: .event, eventStore: eventStore)
        targetCalendar.title = "个人日历"
        targetCalendar.source = source
        eventStore.addMockCalendar(targetCalendar)
    }
    
    override func tearDown() async throws {
        try await super.tearDown()
        eventStore.clearMocks()
        eventStore = nil
        config = nil
        eventMerger = nil
        logger = nil
        testCalendar = nil
        targetCalendar = nil
    }
    
    func testMergeEvents() async throws {
        // 创建两个相似的事件
        let event1 = EKEvent(eventStore: eventStore)
        event1.title = "测试事件"
        event1.startDate = Date()
        event1.endDate = event1.startDate.addingTimeInterval(3600)
        event1.calendar = testCalendar
        try eventStore.save(event1, span: .thisEvent)
        
        let event2 = EKEvent(eventStore: eventStore)
        event2.title = "测试事件"
        event2.startDate = event1.startDate
        event2.endDate = event1.endDate
        event2.calendar = targetCalendar
        try eventStore.save(event2, span: .thisEvent)
        
        // 合并事件
        let events = [event1, event2]
        let mergedEvents = try await eventMerger.mergeEvents(events)
        
        // 验证结果
        XCTAssertEqual(mergedEvents.count, 1, "应该只剩下一个事件")
        XCTAssertEqual(mergedEvents.first?.calendar.title, "个人日历", "事件应该被移动到目标日历")
    }
} 