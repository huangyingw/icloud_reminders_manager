import XCTest
import EventKit
@testable import Core

final class CalendarManagerTests: XCTestCase {
    var mockEventStore: MockEventStore!
    var config: Config!
    var logger: FileLogger!
    var calendarManager: CalendarManager!
    
    override func setUp() {
        super.setUp()
        mockEventStore = MockEventStore()
        config = Config(calendar: CalendarConfig(targetCalendarName: "Test Calendar"),
                       reminder: ReminderConfig(listNames: ["Test List"]))
        logger = FileLogger(label: "test", shouldLog: false)
        calendarManager = CalendarManager(config: config, eventStore: mockEventStore, logger: logger)
        
        // 创建目标日历
        _ = mockEventStore.createMockCalendar(title: "Test Calendar", type: .event)
    }
    
    override func tearDown() {
        mockEventStore = nil
        config = nil
        logger = nil
        calendarManager = nil
        super.tearDown()
    }
    
    func testProcessTargetCalendarEvents() async throws {
        // 创建测试事件
        let calendar = try calendarManager.getTargetCalendar()
        _ = mockEventStore.createMockEvent(title: "Test Event", startDate: Date(), calendar: calendar)
        
        // 处理目标日历事件
        try await calendarManager.processTargetCalendarEvents()
        
        // 验证结果
        let events = mockEventStore.getAllEvents()
        XCTAssertEqual(events.count, 1, "事件数量应该保持不变")
        XCTAssertEqual(events[0].title, "Test Event", "事件标题应该保持不变")
    }
    
    func testProcessSourceCalendars() async throws {
        // 创建源日历
        let sourceCalendar = mockEventStore.createMockCalendar(title: "Source Calendar", type: .event)
        
        // 创建测试事件
        _ = mockEventStore.createMockEvent(title: "Source Event", startDate: Date(), calendar: sourceCalendar)
        
        // 处理源日历
        try await calendarManager.processSourceCalendars()
        
        // 验证结果
        let events = mockEventStore.getAllEvents()
        XCTAssertEqual(events.count, 1, "事件数量应该保持不变")
        XCTAssertEqual(events[0].title, "Source Event", "事件标题应该保持不变")
    }
    
    func testCleanupEmptyCalendars() throws {
        // 创建空日历
        let emptyCalendar = mockEventStore.createMockCalendar(title: "Empty Calendar", type: .event)
        
        // 清理空日历
        try calendarManager.cleanupEmptyCalendars()
        
        // 验证结果
        let calendars = mockEventStore.calendars(for: .event)
        XCTAssertFalse(calendars.contains(where: { $0.calendarIdentifier == emptyCalendar.calendarIdentifier }), "空日历应该被删除")
    }
    
    func testProcessEmptyEvents() async throws {
        // 创建一个空白事件
        let calendar = mockEventStore.createMockCalendar(title: "Test Calendar", type: .event)
        _ = mockEventStore.createMockEvent(title: "   ", startDate: Date(), calendar: calendar)
        
        // 创建一个正常事件
        _ = mockEventStore.createMockEvent(title: "正常事件", startDate: Date(), calendar: calendar)
        
        // 处理事件
        try await calendarManager.processTargetCalendarEvents()
        
        // 验证空白事件被删除，正常事件保留
        let remainingEvents = mockEventStore.events(matching: mockEventStore.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [calendar]
        ))
        
        XCTAssertEqual(remainingEvents.count, 1)
        XCTAssertEqual(remainingEvents.first?.title, "正常事件")
    }
    
    func testProcessDuplicateEvents() async throws {
        // 创建三个标题相同的事件，开始时间不同
        let calendar = mockEventStore.createMockCalendar(title: "Test Calendar", type: .event)
        
        // 使用固定的时间来创建事件
        let baseDate = Date()
        
        _ = mockEventStore.createMockEvent(
            title: "重复事件",
            startDate: baseDate.addingTimeInterval(-86400 * 2),  // 2天前
            calendar: calendar
        )
        
        _ = mockEventStore.createMockEvent(
            title: "重复事件",
            startDate: baseDate.addingTimeInterval(-86400),  // 1天前
            calendar: calendar
        )
        
        let latestEvent = mockEventStore.createMockEvent(
            title: "重复事件",
            startDate: baseDate,  // 现在
            calendar: calendar
        )
        
        // 创建一个不同标题的事件
        _ = mockEventStore.createMockEvent(
            title: "不同的事件",
            startDate: baseDate,
            calendar: calendar
        )
        
        // 处理事件
        try await calendarManager.processTargetCalendarEvents()
        
        // 验证结果
        let remainingEvents = mockEventStore.events(matching: mockEventStore.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [calendar]
        ))
        
        // 应该只剩下两个事件：最新的重复事件和不同标题的事件
        XCTAssertEqual(remainingEvents.count, 2)
        
        // 验证保留的是最新的事件
        let duplicateEvents = remainingEvents.filter { $0.title == "重复事件" }
        XCTAssertEqual(duplicateEvents.count, 1)
        
        // 比较事件的日期组件而不是具体时间
        if let eventDate = duplicateEvents.first?.startDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: eventDate)
            let latestComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: latestEvent.startDate)
            XCTAssertEqual(components.year, latestComponents.year)
            XCTAssertEqual(components.month, latestComponents.month)
            XCTAssertEqual(components.day, latestComponents.day)
            XCTAssertEqual(components.hour, latestComponents.hour)
            XCTAssertEqual(components.minute, latestComponents.minute)
        } else {
            XCTFail("未找到重复事件")
        }
        
        // 验证不同标题的事件保留
        let otherEvents = remainingEvents.filter { $0.title == "不同的事件" }
        XCTAssertEqual(otherEvents.count, 1)
    }
    
    func testProcessRecurringEvents() async throws {
        // 创建一个带有重复规则的循环事件
        let calendar = mockEventStore.createMockCalendar(title: "Test Calendar", type: .event)
        let baseDate = Date()
        
        // 创建一个每月重复的事件
        let recurringEvent = mockEventStore.createMockEvent(
            title: "循环事件",
            startDate: baseDate,
            calendar: calendar
        )
        
        // 添加每月重复的规则
        let recurrenceRule = EKRecurrenceRule(
            recurrenceWith: .monthly,
            interval: 1,
            end: nil
        )
        recurringEvent.recurrenceRules = [recurrenceRule]
        
        // 创建另一个相同标题但不是循环的事件
        _ = mockEventStore.createMockEvent(
            title: "循环事件",
            startDate: baseDate.addingTimeInterval(86400),
            calendar: calendar
        )
        
        // 处理事件
        try await calendarManager.processTargetCalendarEvents()
        
        // 验证结果
        let remainingEvents = mockEventStore.events(matching: mockEventStore.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [calendar]
        ))
        
        // 应该保留两个事件：循环事件和重复事件
        XCTAssertEqual(remainingEvents.count, 2, "循环事件和重复事件都应该保留")
        
        // 验证循环事件的重复规则被保留
        let recurringEvents = remainingEvents.filter { $0.recurrenceRules?.isEmpty == false }
        XCTAssertEqual(recurringEvents.count, 1, "应该有一个循环事件")
        XCTAssertEqual(recurringEvents.first?.recurrenceRules?.first?.frequency, .monthly, "循环规则应该保持不变")
    }
} 