import XCTest
import EventKit
@testable import Core

final class CalendarManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var logger: FileLogger!
    var config: Config!
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
    
    func testProcessTargetCalendarEvents() async throws {
        // 创建测试事件
        let calendar = try calendarManager.getTargetCalendar()
        _ = eventStore.createMockEvent(title: "Test Event", startDate: Date(), calendar: calendar)
        
        // 处理目标日历事件
        try await calendarManager.processTargetCalendarEvents()
        
        // 验证结果
        let events = eventStore.getAllEvents()
        XCTAssertEqual(events.count, 1, "事件数量应该保持不变")
        XCTAssertEqual(events[0].title, "Test Event", "事件标题应该保持不变")
    }
    
    func testProcessSourceCalendars() async throws {
        // 创建源日历
        let sourceCalendar = eventStore.createMockCalendar(title: "Source Calendar", type: .event)
        
        // 创建测试事件
        _ = eventStore.createMockEvent(title: "Source Event", startDate: Date(), calendar: sourceCalendar)
        
        // 处理源日历
        try await calendarManager.processSourceCalendars()
        
        // 验证结果
        let events = eventStore.getAllEvents()
        XCTAssertEqual(events.count, 1, "事件数量应该保持不变")
        XCTAssertEqual(events[0].title, "Source Event", "事件标题应该保持不变")
    }
    
    func testCleanupEmptyCalendars() throws {
        // 创建空日历
        let emptyCalendar = eventStore.createMockCalendar(title: "Empty Calendar", type: .event)
        
        // 清理空日历
        try calendarManager.cleanupEmptyCalendars()
        
        // 验证结果
        let calendars = eventStore.calendars(for: .event)
        XCTAssertFalse(calendars.contains(where: { $0.calendarIdentifier == emptyCalendar.calendarIdentifier }), "空日历应该被删除")
    }
} 