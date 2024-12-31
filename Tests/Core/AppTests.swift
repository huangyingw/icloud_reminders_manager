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
    
    func testProcessExpiredEvents() async throws {
        // 创建测试日历
        let sourceCalendar = EKCalendar(for: .event, eventStore: eventStore)
        sourceCalendar.title = "测试日历"
        sourceCalendar.source = MockSource()
        
        let targetCalendar = EKCalendar(for: .event, eventStore: eventStore)
        targetCalendar.title = "个人日历"
        targetCalendar.source = MockSource()
        
        // 创建过期事件
        let expiredEvent = EKEvent(eventStore: eventStore)
        expiredEvent.title = "过期事件"
        expiredEvent.startDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        expiredEvent.endDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        expiredEvent.calendar = sourceCalendar
        
        // 创建未过期事件
        let activeEvent = EKEvent(eventStore: eventStore)
        activeEvent.title = "未过期事件"
        activeEvent.startDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        activeEvent.endDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        activeEvent.calendar = sourceCalendar
        
        // 创建正在进行的事件
        let ongoingEvent = EKEvent(eventStore: eventStore)
        ongoingEvent.title = "正在进行的事件"
        ongoingEvent.startDate = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        ongoingEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        ongoingEvent.calendar = sourceCalendar
        
        // 创建重复事件
        let recurringEvent = EKEvent(eventStore: eventStore)
        recurringEvent.title = "重复事件"
        recurringEvent.startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        recurringEvent.endDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recurrenceRule = EKRecurrenceRule(
            recurrenceWith: .weekly,
            interval: 1,
            end: nil
        )
        recurringEvent.recurrenceRules = [recurrenceRule]
        recurringEvent.calendar = sourceCalendar
        
        // 添加事件到 MockEventStore
        eventStore.calendars = [sourceCalendar, targetCalendar]
        eventStore.events = [expiredEvent, activeEvent, ongoingEvent, recurringEvent]
        
        // 运行测试
        try await app.processExpiredEvents()
        
        // 验证结果
        XCTAssertEqual(expiredEvent.calendar.title, "个人日历", "过期事件应该被移动到目标日历")
        XCTAssertEqual(activeEvent.calendar.title, "测试日历", "未过期事件不应该被移动")
        XCTAssertEqual(ongoingEvent.calendar.title, "测试日历", "正在进行的事件不应该被移动")
        XCTAssertEqual(recurringEvent.calendar.title, "测试日历", "重复事件不应该被移动，因为它们可能还有未来的实例")
    }
} 