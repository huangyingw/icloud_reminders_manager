import XCTest
import EventKit
@testable import Core

final class AppTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: FileLogger!
    var app: App!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        logger = FileLogger(label: "test")
        config = Config(calendar: CalendarConfig(targetCalendarName: "Test Calendar"),
                       reminder: ReminderConfig(listNames: ["Test List"]))
        app = App(config: config, eventStore: eventStore, logger: logger)
        
        // 创建目标日历
        _ = eventStore.createMockCalendar(title: "Test Calendar", type: .event)
    }
    
    override func tearDown() {
        eventStore.clearMocks()
        eventStore = nil
        config = nil
        logger = nil
        app = nil
        super.tearDown()
    }
    
    func testProcessExpiredEvents() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "源日历", type: .event)
        let targetCalendar = try getTargetCalendar()
        
        // 创建过期事件
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        _ = eventStore.createMockEvent(title: "过期事件", startDate: pastDate, calendar: sourceCalendar)
        
        // 处理过期事件
        try await app.run()
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertEqual(events.count, 1, "应该有一个事件被移动到目标日历")
        XCTAssertEqual(events[0].title, "过期事件", "事件标题应该保持不变")
        
        // 验证源日历是否为空
        let sourceEvents = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == sourceCalendar.calendarIdentifier }
        XCTAssertTrue(sourceEvents.isEmpty, "源日历应该为空")
    }
    
    func testProcessEmptyCalendar() async throws {
        // 创建空日历
        let emptyCalendar = eventStore.createMockCalendar(title: "空日历", type: .event)
        let targetCalendar = try getTargetCalendar()
        
        // 处理过期事件（没有事件）
        try await app.run()
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertTrue(events.isEmpty, "不应该有事件被移动")
        
        // 验证空日历是否被删除
        let calendars = eventStore.calendars(for: .event)
        XCTAssertFalse(calendars.contains(where: { $0.calendarIdentifier == emptyCalendar.calendarIdentifier }), "空日历应该被删除")
    }
    
    private func getTargetCalendar() throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        guard let targetCalendar = calendars.first(where: { $0.title == config.calendar.targetCalendarName }) else {
            throw CalendarError.targetCalendarNotFound
        }
        return targetCalendar
    }
} 