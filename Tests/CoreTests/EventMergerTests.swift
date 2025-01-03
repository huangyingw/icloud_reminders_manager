import XCTest
import EventKit
@testable import Core

final class EventMergerTests: XCTestCase {
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
    }
    
    func testGetICloudCalendars() {
        // 创建 iCloud 源
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建日历
        let calendar = eventStore.createMockCalendar(title: "iCloud Calendar", type: .event)
        calendar.source = iCloudSource
        
        // 获取 iCloud 日历
        let iCloudCalendars = calendarManager.getICloudCalendars()
        
        // 验证结果
        XCTAssertEqual(iCloudCalendars.count, 1, "应该找到一个 iCloud 日历")
        XCTAssertEqual(iCloudCalendars[0].title, "iCloud Calendar", "日历标题应该匹配")
    }
    
    override func tearDown() {
        eventStore.clearMocks()
        eventStore = nil
        config = nil
        logger = nil
        calendarManager = nil
        super.tearDown()
    }
} 