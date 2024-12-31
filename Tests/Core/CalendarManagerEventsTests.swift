import XCTest
import EventKit
@testable import Core

class CalendarManagerEventsTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: Logger!
    var calendarManager: CalendarManager!
    
    override func setUp() {
        super.setUp()
        
        eventStore = MockEventStore()
        config = Config(targetCalendarName: "个人日历")
        logger = Logger()
        calendarManager = CalendarManager(eventStore: eventStore, config: config, logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        logger = nil
        calendarManager = nil
        
        super.tearDown()
    }
    
    func testMoveEventToTargetCalendar() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "工作", type: .event)
        let targetCalendar = eventStore.createMockCalendar(title: "个人日历", type: .event)
        
        // 创建事件
        let event = eventStore.createMockEvent(
            title: "测试事件",
            startDate: Date(),
            calendar: sourceCalendar
        )
        
        // 移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证事件已被移动到目标日历
        XCTAssertEqual(eventStore.savedEvents.count, 1)
        let savedEvent = eventStore.savedEvents[0].event
        XCTAssertEqual(savedEvent.title, "测试事件")
        XCTAssertEqual(savedEvent.calendar, targetCalendar)
        
        // 验证原事件已被删除
        XCTAssertTrue(eventStore.removedEvents.contains(event))
    }
    
    func testMoveEventToTargetCalendarWhenAlreadyInTarget() async throws {
        // 创建目标日历
        let targetCalendar = eventStore.createMockCalendar(title: "个人日历", type: .event)
        
        // 创建已在目标日历中的事件
        let event = eventStore.createMockEvent(
            title: "测试事件",
            startDate: Date(),
            calendar: targetCalendar
        )
        
        // 移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证没有进行任何操作
        XCTAssertTrue(eventStore.savedEvents.isEmpty)
        XCTAssertTrue(eventStore.removedEvents.isEmpty)
    }
    
    func testMoveEventToTargetCalendarWithNoTargetCalendar() async throws {
        // 创建源日历
        let sourceCalendar = eventStore.createMockCalendar(title: "工作", type: .event)
        
        // 创建事件
        let event = eventStore.createMockEvent(
            title: "测试事件",
            startDate: Date(),
            calendar: sourceCalendar
        )
        
        // 移动事件到目标日历应该抛出错误
        do {
            try await calendarManager.moveEventToTargetCalendar(event)
            XCTFail("应该抛出错误")
        } catch let error as CalendarError {
            XCTAssertEqual(error, .noCalendarsAvailable)
        }
        
        // 验证没有进行任何操作
        XCTAssertTrue(eventStore.savedEvents.isEmpty)
        XCTAssertTrue(eventStore.removedEvents.isEmpty)
    }
} 