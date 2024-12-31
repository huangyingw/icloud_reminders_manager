import XCTest
import EventKit
@testable import Core

class CalendarAccountManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: Core.Logger!
    var calendarManager: CalendarManager!
    var iCloudSource: EKSource!
    
    override func setUp() {
        super.setUp()
        
        eventStore = MockEventStore()
        config = Config(targetCalendarName: "个人")
        logger = Core.Logger()
        
        // 创建模拟的 iCloud 源
        iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        calendarManager = CalendarManager(eventStore: eventStore, config: config, logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        logger = nil
        calendarManager = nil
        iCloudSource = nil
        super.tearDown()
    }
    
    func testGetICloudCalendars() {
        // 创建一些测试日历
        let calendar1 = eventStore.createMockCalendar(title: "日历1")
        calendar1.source = iCloudSource
        
        let calendar2 = eventStore.createMockCalendar(title: "日历2")
        calendar2.source = iCloudSource
        
        // 创建一个非 iCloud 源的日历
        let localSource = eventStore.createMockSource(title: "本地", type: .local)
        let localCalendar = eventStore.createMockCalendar(title: "本地日历")
        localCalendar.source = localSource
        
        // 获取 iCloud 日历
        let iCloudCalendars = calendarManager.getICloudCalendars()
        
        // 验证结果
        XCTAssertEqual(iCloudCalendars.count, 2)
        XCTAssertTrue(iCloudCalendars.contains(calendar1))
        XCTAssertTrue(iCloudCalendars.contains(calendar2))
        XCTAssertFalse(iCloudCalendars.contains(localCalendar))
    }
    
    func testMoveEventToCurrentWeek() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "源日历")
        sourceCalendar.source = iCloudSource
        
        let targetCalendar = eventStore.createMockCalendar(title: "个人")
        targetCalendar.source = iCloudSource
        
        // 创建一个过期事件
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let event = eventStore.createMockEvent(title: "测试事件", startDate: pastDate, calendar: sourceCalendar)
        
        // 移动事件到当前周
        try await calendarManager.moveEventToCurrentWeek(event)
        
        // 验证事件是否被移动到目标日历
        XCTAssertEqual(event.calendar, targetCalendar)
        
        // 验证事件是否被移动到当前周
        let calendar = Calendar.current
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let currentWeekEnd = calendar.date(byAdding: .day, value: 7, to: currentWeekStart)!
        
        XCTAssertTrue(event.startDate >= currentWeekStart && event.startDate < currentWeekEnd)
    }
    
    func testMoveEventToTargetCalendar() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "源日历")
        let targetCalendar = eventStore.createMockCalendar(title: "个人")
        
        // 创建事件
        let event = eventStore.createMockEvent(
            title: "测试事件",
            startDate: Date(),
            calendar: sourceCalendar
        )
        
        // 移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证事件已被移动到目标日历
        let events = try await calendarManager.getEvents(in: targetCalendar)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].title, "测试事件")
        XCTAssertEqual(events[0].calendar, targetCalendar)
    }
    
    func testGetTargetCalendar() throws {
        // 创建目标日历
        let targetCalendar = eventStore.createMockCalendar(title: "个人")
        targetCalendar.source = iCloudSource
        
        // 获取目标日历
        let result = try calendarManager.getTargetCalendar()
        
        // 验证结果
        XCTAssertEqual(result, targetCalendar)
    }
} 