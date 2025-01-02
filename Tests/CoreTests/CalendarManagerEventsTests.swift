import XCTest
import EventKit
@testable import Core

final class CalendarManagerEventsTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: FileLogger!
    var calendarManager: CalendarManager!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        config = Config(
            calendar: CalendarConfig(targetCalendarName: "个人"),
            reminder: ReminderConfig(listNames: ["提醒事项"])
        )
        logger = FileLogger(label: "test.logger")
        calendarManager = CalendarManager(config: config, eventStore: eventStore, logger: logger)
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
        let targetCalendar = eventStore.createMockCalendar(title: "个人", type: .event)
        
        // 创建事件
        let event = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: sourceCalendar)
        
        // 移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证事件是否被移动到目标日历
        let targetEvents = eventStore.getAllEvents().filter { $0.calendar == targetCalendar }
        XCTAssertEqual(targetEvents.count, 1, "目标日历应该包含一个事件")
        XCTAssertEqual(targetEvents[0].title, "测试事件", "事件标题应该保持不变")
        
        // 验证源日历是否为空
        let sourceEvents = eventStore.getAllEvents().filter { $0.calendar == sourceCalendar }
        XCTAssertTrue(sourceEvents.isEmpty, "源日历应该为空")
    }
    
    func testMoveEventToTargetCalendarWhenAlreadyInTarget() async throws {
        // 创建目标日历
        let targetCalendar = eventStore.createMockCalendar(title: "个人", type: .event)
        
        // 创建已在目标日历中的事件
        let event = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: targetCalendar)
        
        // 尝试移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证事件仍然在目标日历中
        let targetEvents = eventStore.getAllEvents().filter { $0.calendar == targetCalendar }
        XCTAssertEqual(targetEvents.count, 1, "目标日历应该仍然包含一个事件")
        XCTAssertEqual(targetEvents[0].title, "测试事件", "事件标题应该保持不变")
    }
} 