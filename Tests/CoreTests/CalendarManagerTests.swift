import XCTest
import EventKit
import Logging
@testable import Core

final class CalendarManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var calendarManager: CalendarManager!
    var logger: Logger!
    var testCalendar: EKCalendar!
    var targetCalendar: EKCalendar!
    
    override func setUp() async throws {
        try await super.setUp()
        eventStore = MockEventStore()
        config = Config(targetCalendarName: "个人日历")
        logger = Logger(label: "test")
        calendarManager = CalendarManager(eventStore: eventStore, config: config, logger: logger)
        
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
        calendarManager = nil
        logger = nil
        testCalendar = nil
        targetCalendar = nil
    }
    
    func testGetICloudCalendars() throws {
        let calendars = calendarManager.getICloudCalendars()
        XCTAssertFalse(calendars.isEmpty, "应该至少找到一个可用日历")
        XCTAssertTrue(calendars.contains { $0.title == "测试日历" }, "应该找到测试日历")
    }
    
    func testGetTargetCalendar() async throws {
        let targetCalendar = try calendarManager.getTargetCalendar()
        XCTAssertEqual(targetCalendar.title, "个人日历", "应该找到目标日历")
    }
} 