import XCTest
import EventKit
@testable import Core

final class CalendarAccountManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: FileLogger!
    var calendarManager: CalendarManager!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        logger = FileLogger(label: "test")
        config = Config(calendar: CalendarConfig(targetCalendarName: "Test Calendar"),
                       reminder: ReminderConfig(listNames: ["Test List"]))
        calendarManager = CalendarManager(config: config, eventStore: eventStore, logger: logger)
        
        // 创建目标日历
        _ = eventStore.createMockCalendar(title: "Test Calendar", type: .event)
    }
    
    override func tearDown() {
        eventStore.clearMocks()
        eventStore = nil
        logger = nil
        config = nil
        calendarManager = nil
        super.tearDown()
    }
    
    func testMoveEventsToTargetCalendar() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "源日历", type: .event)
        let targetCalendar = try calendarManager.getTargetCalendar()
        
        // 创建事件
        let event = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: sourceCalendar)
        
        // 移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertEqual(events.count, 1, "应该有一个事件被移动到目标日历")
        XCTAssertEqual(events[0].title, "测试事件", "事件标题应该保持不变")
    }
    
    func testMoveEventsToTargetCalendarWithEmptyCalendar() async throws {
        // 创建空日历和目标日历
        let emptyCalendar = eventStore.createMockCalendar(title: "空日历", type: .event)
        let targetCalendar = try calendarManager.getTargetCalendar()
        
        // 移动事件到目标日历（没有事件）
        try await calendarManager.processSourceCalendars()
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertTrue(events.isEmpty, "不应该有事件被移动")
        
        // 验证空日历是否被删除
        let calendars = eventStore.calendars(for: .event)
        XCTAssertFalse(calendars.contains(where: { $0.calendarIdentifier == emptyCalendar.calendarIdentifier }), "空日历应该被删除")
    }
} 