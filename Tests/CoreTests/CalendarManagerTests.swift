import XCTest
import EventKit
@testable import Core

final class CalendarManagerTests: XCTestCase {
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
    
    func testGetICloudCalendars() {
        // 创建 iCloud 源
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建测试日历
        let calendar1 = eventStore.createMockCalendar(title: "日历1", type: .event)
        calendar1.setValue(iCloudSource, forKey: "source")
        
        let calendar2 = eventStore.createMockCalendar(title: "日历2", type: .event)
        calendar2.setValue(iCloudSource, forKey: "source")
        
        // 获取 iCloud 日历
        let iCloudCalendars = calendarManager.getICloudCalendars()
        
        // 验证结果
        XCTAssertEqual(iCloudCalendars.count, 2, "应该找到两个 iCloud 日历")
        XCTAssertTrue(iCloudCalendars.contains(calendar1))
        XCTAssertTrue(iCloudCalendars.contains(calendar2))
    }
    
    func testGetTargetCalendar() throws {
        // 创建目标日历
        let targetCalendar = eventStore.createMockCalendar(title: "个人", type: .event)
        
        // 获取目标日历
        let result = try calendarManager.getTargetCalendar()
        
        // 验证结果
        XCTAssertEqual(result, targetCalendar)
    }
    
    func testGetTargetCalendarNotFound() {
        // 不创建目标日历
        
        // 尝试获取目标日历
        XCTAssertThrowsError(try calendarManager.getTargetCalendar()) { error in
            XCTAssertEqual(error as? CalendarError, .targetCalendarNotFound)
        }
    }
    
    func testIsCalendarEmpty() {
        // 创建空日历
        let emptyCalendar = eventStore.createMockCalendar(title: "空日历", type: .event)
        XCTAssertTrue(calendarManager.isCalendarEmpty(emptyCalendar), "新创建的日历应该为空")
        
        // 创建非空日历
        let nonEmptyCalendar = eventStore.createMockCalendar(title: "非空日历", type: .event)
        let _ = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: nonEmptyCalendar)
        XCTAssertFalse(calendarManager.isCalendarEmpty(nonEmptyCalendar), "包含事件的日历不应该为空")
    }
    
    func testDeleteEmptyCalendar() throws {
        // 创建空日历
        let emptyCalendar = eventStore.createMockCalendar(title: "空日历", type: .event)
        XCTAssertTrue(calendarManager.isCalendarEmpty(emptyCalendar), "新创建的日历应该为空")
        
        // 删除空日历
        try calendarManager.deleteEmptyCalendar(emptyCalendar)
        XCTAssertFalse(eventStore.calendars(for: .event).contains(emptyCalendar), "空日历应该被删除")
        
        // 创建非空日历
        let nonEmptyCalendar = eventStore.createMockCalendar(title: "非空日历", type: .event)
        let _ = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: nonEmptyCalendar)
        
        // 尝试删除非空日历
        try calendarManager.deleteEmptyCalendar(nonEmptyCalendar)
        XCTAssertTrue(eventStore.calendars(for: .event).contains(nonEmptyCalendar), "非空日历不应该被删除")
        
        // 尝试删除目标日历
        let targetCalendar = eventStore.createMockCalendar(title: "个人", type: .event)
        try calendarManager.deleteEmptyCalendar(targetCalendar)
        XCTAssertTrue(eventStore.calendars(for: .event).contains(targetCalendar), "目标日历不应该被删除，即使它是空的")
    }
} 