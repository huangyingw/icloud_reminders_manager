import XCTest
import EventKit
@testable import Core

class AppTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: Core.Logger!
    var app: CalendarApp!
    
    override func setUp() {
        super.setUp()
        
        eventStore = MockEventStore()
        config = Config(targetCalendarName: "个人")
        logger = Core.Logger()
        app = CalendarApp(eventStore: eventStore, config: config, logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        logger = nil
        app = nil
        super.tearDown()
    }
    
    func testHistoricalEventHandling() async throws {
        // 创建模拟的 iCloud 源
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建测试日历
        let calendar = eventStore.createMockCalendar(title: "个人")
        calendar.source = iCloudSource
        
        // 创建一些历史事件
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let event1 = eventStore.createMockEvent(title: "过期事件1", startDate: pastDate, calendar: calendar)
        let event2 = eventStore.createMockEvent(title: "过期事件2", startDate: pastDate, calendar: calendar)
        
        // 运行应用
        try await app.run()
        
        // 验证事件是否被移动到当前周
        let currentWeekStart = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let currentWeekEnd = Calendar.current.date(byAdding: .day, value: 7, to: currentWeekStart)!
        
        XCTAssertTrue(event1.startDate >= currentWeekStart && event1.startDate < currentWeekEnd)
        XCTAssertTrue(event2.startDate >= currentWeekStart && event2.startDate < currentWeekEnd)
    }
    
    func testEventDeduplication() async throws {
        // 创建模拟的 iCloud 源
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建测试日历
        let calendar = eventStore.createMockCalendar(title: "个人")
        calendar.source = iCloudSource
        
        // 创建多个具有相同标题的事件
        let startDate = Date()
        let event1 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        let event2 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        let event3 = eventStore.createMockEvent(title: "重复事件", startDate: startDate, calendar: calendar)
        
        // 运行应用
        try await app.run()
        
        // 验证重复事件是否被合并
        XCTAssertEqual(eventStore.mockEvents.count, 1)
        XCTAssertTrue(eventStore.mockEvents.contains { $0.title == "重复事件" })
    }
} 