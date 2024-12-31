import XCTest
import EventKit
@testable import icloud_reminders_manager

final class MainTests: XCTestCase {
    var eventStore: MockEventStore!
    var app: App!
    var config: Config!
    var logger: MockLogger!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        config = Config(targetCalendarName: "个人")
        logger = MockLogger()
        app = App(eventStore: eventStore, config: config, logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        app = nil
        config = nil
        logger = nil
        super.tearDown()
    }
    
    func testRequestAccess() async throws {
        // 测试权限请求
        try await app.requestAccess()
        XCTAssertTrue(eventStore.didRequestEventAccess)
        XCTAssertTrue(eventStore.didRequestReminderAccess)
    }
    
    func testProcessReminders() async throws {
        // 创建测试数据
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        let reminderList = eventStore.createMockCalendar(for: .reminder, title: "提醒", source: iCloudSource)
        let targetCalendar = eventStore.createMockCalendar(for: .event, title: "个人", source: iCloudSource)
        
        // 创建一些测试提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let reminder = eventStore.createMockReminder(title: "测试提醒", dueDate: pastDate, calendar: reminderList)
        try eventStore.save(reminder, commit: true)
        
        // 处理提醒
        try await app.processReminders()
        
        // 验证结果
        XCTAssertTrue(reminder.isCompleted)
        XCTAssertEqual(eventStore.savedEvents.count, 1)
        
        let savedEvent = eventStore.savedEvents[0].event
        XCTAssertEqual(savedEvent.title, "测试提醒")
        XCTAssertEqual(savedEvent.calendar, targetCalendar)
    }
    
    func testProcessReminderList() async throws {
        // 创建测试数据
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        let reminderList = eventStore.createMockCalendar(for: .reminder, title: "提醒", source: iCloudSource)
        _ = eventStore.createMockCalendar(for: .event, title: "个人", source: iCloudSource)
        
        // 创建测试提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let reminder = eventStore.createMockReminder(title: "测试提醒", dueDate: pastDate, calendar: reminderList)
        try eventStore.save(reminder, commit: true)
        
        // 处理提醒列表
        try await app.processReminderList(reminderList)
        
        // 验证结果
        XCTAssertTrue(reminder.isCompleted)
        XCTAssertEqual(eventStore.savedEvents.count, 1)
    }
    
    func testProcessReminder() async throws {
        // 创建测试数据
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        let reminderList = eventStore.createMockCalendar(for: .reminder, title: "提醒", source: iCloudSource)
        _ = eventStore.createMockCalendar(for: .event, title: "个人", source: iCloudSource)
        
        // 创建测试提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let reminder = eventStore.createMockReminder(title: "测试提醒", dueDate: pastDate, calendar: reminderList)
        
        // 处理提醒
        try await app.processReminder(reminder)
        
        // 验证结果
        XCTAssertTrue(reminder.isCompleted)
        XCTAssertEqual(eventStore.savedEvents.count, 1)
    }
} 