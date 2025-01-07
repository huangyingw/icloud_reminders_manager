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
        logger = FileLogger(label: "test", shouldLog: false)
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
    
    func testMoveEventToTargetCalendar() async throws {
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
    
    func testMoveEventToTargetCalendarWithInvalidEvent() async throws {
        // 获取目标日历
        let targetCalendar = try calendarManager.getTargetCalendar()
        
        // 创建事件（已经在目标日历中）
        let event = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: targetCalendar)
        
        // 移动事件到目标日历（应该被跳过）
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertEqual(events.count, 1, "事件数量应该保持不变")
        XCTAssertEqual(events[0].title, "测试事件", "事件标题应该保持不变")
    }
    
    func testMoveExpiredEventToTargetCalendar() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "源日历", type: .event)
        let targetCalendar = try calendarManager.getTargetCalendar()
        
        // 创建一个过期的事件（上周三下午3点）
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // 星期一为一周的第一天
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday, .hour, .minute], from: lastWeek)
        components.weekday = 4  // 星期三
        components.hour = 15    // 下午3点
        components.minute = 0
        let pastDate = calendar.date(from: components)!
        let event = eventStore.createMockEvent(title: "过期事件", startDate: pastDate, calendar: sourceCalendar)
        event.endDate = calendar.date(byAdding: .hour, value: 1, to: pastDate)!
        
        // 移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertEqual(events.count, 1, "应该有一个事件被移动到目标日历")
        XCTAssertEqual(events[0].title, "过期事件", "事件标题应该保持不变")
        
        // 验证新事件的时间
        let newEvent = events[0]
        let newComponents = calendar.dateComponents([.weekday, .hour, .minute], from: newEvent.startDate)
        XCTAssertEqual(newComponents.weekday, 4, "事件应该在本周三")
        XCTAssertEqual(newComponents.hour, 15, "事件应该在下午3点")
        XCTAssertEqual(newComponents.minute, 0, "事件应该在整点")
        
        // 验证事件持续时间
        let duration = newEvent.endDate.timeIntervalSince(newEvent.startDate)
        XCTAssertEqual(duration, 3600, "事件应该持续1小时")
        
        // 验证事件是否在本周
        let thisWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let eventWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newEvent.startDate)
        XCTAssertEqual(eventWeek.yearForWeekOfYear, thisWeek.yearForWeekOfYear, "事件应该在今年")
        XCTAssertEqual(eventWeek.weekOfYear, thisWeek.weekOfYear, "事件应该在本周")
    }
    
    func testProcessTargetCalendarExpiredEvents() async throws {
        // 获取目标日历
        let targetCalendar = try calendarManager.getTargetCalendar()
        
        // 创建一个过期的事件（上周二下午2点）
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // 星期一为一周的第一天
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday, .hour, .minute], from: lastWeek)
        components.weekday = 3  // 星期二
        components.hour = 14    // 下午2点
        components.minute = 0
        let pastDate = calendar.date(from: components)!
        
        let event = eventStore.createMockEvent(title: "目标日历中的过期事件", startDate: pastDate, calendar: targetCalendar)
        event.endDate = calendar.date(byAdding: .hour, value: 2, to: pastDate)! // 2小时的事件
        
        // 处理目标日历中的事件
        try await calendarManager.processTargetCalendarEvents()
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertEqual(events.count, 1, "应该只有一个事件")
        
        let newEvent = events[0]
        XCTAssertEqual(newEvent.title, "目标日历中的过期事件", "事件标题应该保持不变")
        
        // 验证新事件的时间
        let newComponents = calendar.dateComponents([.weekday, .hour, .minute], from: newEvent.startDate)
        XCTAssertEqual(newComponents.weekday, 3, "事件应该在本周二")
        XCTAssertEqual(newComponents.hour, 14, "事件应该在下午2点")
        XCTAssertEqual(newComponents.minute, 0, "事件应该在整点")
        
        // 验证事件持续时间
        let duration = newEvent.endDate.timeIntervalSince(newEvent.startDate)
        XCTAssertEqual(duration, 7200, "事件应该持续2小时")
        
        // 验证事件是否在本周
        let thisWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let eventWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newEvent.startDate)
        XCTAssertEqual(eventWeek.yearForWeekOfYear, thisWeek.yearForWeekOfYear, "事件应该在今年")
        XCTAssertEqual(eventWeek.weekOfYear, thisWeek.weekOfYear, "事件应该在本周")
    }
    
    func testMoveEventToTargetCalendarWithAlarms() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "源日历", type: .event)
        let targetCalendar = try calendarManager.getTargetCalendar()
        
        // 创建事件
        let event = eventStore.createMockEvent(title: "带提醒的测试事件", startDate: Date(), calendar: sourceCalendar)
        
        // 添加提醒
        let alarm1 = EKAlarm(relativeOffset: -3600) // 1小时前提醒
        let alarm2 = EKAlarm(relativeOffset: -300)  // 5分钟前提醒
        event.addAlarm(alarm1)
        event.addAlarm(alarm2)
        
        // 移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertEqual(events.count, 1, "应该有一个事件被移动到目标日历")
        
        let newEvent = events[0]
        XCTAssertEqual(newEvent.title, "带提醒的测试事件", "事件标题应该保持不变")
        
        // 验证提醒是否被正确复制
        XCTAssertNotNil(newEvent.alarms, "新事件应该有提醒")
        XCTAssertEqual(newEvent.alarms?.count, 2, "新事件应该有2个提醒")
        
        let alarmOffsets = newEvent.alarms?.map { $0.relativeOffset }.sorted()
        XCTAssertEqual(alarmOffsets, [-3600, -300], "提醒的时间偏移应该保持不变")
    }
    
    func testMoveExpiredEventToCurrentWeekWithAlarms() async throws {
        // 获取目标日历
        let targetCalendar = try calendarManager.getTargetCalendar()
        
        // 创建一个过期的事件（上周二下午2点）
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // 星期一为一周的第一天
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear, .weekday, .hour, .minute], from: lastWeek)
        components.weekday = 3  // 星期二
        components.hour = 14    // 下午2点
        components.minute = 0
        let pastDate = calendar.date(from: components)!
        
        let event = eventStore.createMockEvent(title: "带提醒的过期事件", startDate: pastDate, calendar: targetCalendar)
        event.endDate = calendar.date(byAdding: .hour, value: 2, to: pastDate)! // 2小时的事件
        
        // 添加提醒
        let alarm1 = EKAlarm(relativeOffset: -3600) // 1小时前提醒
        let alarm2 = EKAlarm(relativeOffset: -300)  // 5分钟前提醒
        event.addAlarm(alarm1)
        event.addAlarm(alarm2)
        
        // 处理目标日历中的事件
        try await calendarManager.processTargetCalendarEvents()
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertEqual(events.count, 1, "应该只有一个事件")
        
        let newEvent = events[0]
        XCTAssertEqual(newEvent.title, "带提醒的过期事件", "事件标题应该保持不变")
        
        // 验证提醒是否被正确复制
        XCTAssertNotNil(newEvent.alarms, "新事件应该有提醒")
        XCTAssertEqual(newEvent.alarms?.count, 2, "新事件应该有2个提醒")
        
        let alarmOffsets = newEvent.alarms?.map { $0.relativeOffset }.sorted()
        XCTAssertEqual(alarmOffsets, [-3600, -300], "提醒的时间偏移应该保持不变")
        
        // 验证事件是否在本周
        let thisWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let eventWeek = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: newEvent.startDate)
        XCTAssertEqual(eventWeek.yearForWeekOfYear, thisWeek.yearForWeekOfYear, "事件应该在今年")
        XCTAssertEqual(eventWeek.weekOfYear, thisWeek.weekOfYear, "事件应该在本周")
    }
} 