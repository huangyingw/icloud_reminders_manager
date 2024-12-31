import XCTest
import EventKit
@testable import Core

class RemindersManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: Logger!
    var remindersManager: ReminderManager!
    
    override func setUp() {
        super.setUp()
        
        eventStore = MockEventStore()
        config = Config(targetCalendarName: "个人日历")
        logger = Logger()
        remindersManager = ReminderManager(eventStore: eventStore, config: config, logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        logger = nil
        remindersManager = nil
        
        super.tearDown()
    }
    
    func testGetExpiredReminders() async throws {
        // 创建提醒事项列表
        let reminderList = eventStore.createMockCalendar(title: "提醒事项", type: .reminder)
        
        // 创建过期提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let expiredReminder = eventStore.createMockReminder(
            title: "过期提醒",
            dueDate: pastDate,
            calendar: reminderList
        )
        
        // 创建未过期提醒
        let futureDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let activeReminder = eventStore.createMockReminder(
            title: "未过期提醒",
            dueDate: futureDate,
            calendar: reminderList
        )
        
        // 创建无截止日期提醒
        let noDueDateReminder = eventStore.createMockReminder(
            title: "无截止日期提醒",
            dueDate: nil,
            calendar: reminderList
        )
        
        // 获取过期提醒
        let expiredReminders = try await remindersManager.getExpiredReminders(from: reminderList)
        
        // 验证结果
        XCTAssertEqual(expiredReminders.count, 1)
        XCTAssertEqual(expiredReminders.first?.title, "过期提醒")
    }
    
    func testProcessReminder() async throws {
        // 创建提醒事项列表
        let reminderList = eventStore.createMockCalendar(title: "提醒事项", type: .reminder)
        
        // 创建目标日历
        let targetCalendar = eventStore.createMockCalendar(title: "个人日历", type: .event)
        
        // 创建过期提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let reminder = eventStore.createMockReminder(
            title: "过期提醒",
            dueDate: pastDate,
            calendar: reminderList
        )
        
        // 处理提醒
        try await remindersManager.processReminder(reminder)
        
        // 验证提醒已被标记为完成
        XCTAssertTrue(reminder.isCompleted)
        XCTAssertTrue(eventStore.savedReminders.contains { saved in
            saved.reminder == reminder && saved.commit
        })
        
        // 验证事件已被创建
        XCTAssertEqual(eventStore.savedEvents.count, 1)
        let savedEvent = eventStore.savedEvents[0].event
        XCTAssertEqual(savedEvent.title, "过期提醒")
        XCTAssertEqual(savedEvent.calendar, targetCalendar)
    }
    
    func testProcessReminderWithEmptyTitle() async throws {
        // 创建提醒事项列表
        let reminderList = eventStore.createMockCalendar(title: "提醒事项", type: .reminder)
        
        // 创建过期提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let reminder = eventStore.createMockReminder(
            title: "",
            dueDate: pastDate,
            calendar: reminderList
        )
        
        // 处理提醒
        try await remindersManager.processReminder(reminder)
        
        // 验证提醒已被标记为完成
        XCTAssertTrue(reminder.isCompleted)
        XCTAssertTrue(eventStore.savedReminders.contains { saved in
            saved.reminder == reminder && saved.commit
        })
        
        // 验证没有创建事件
        XCTAssertTrue(eventStore.savedEvents.isEmpty)
    }
    
    func testProcessReminderWithNoDueDate() async throws {
        // 创建提醒事项列表
        let reminderList = eventStore.createMockCalendar(title: "提醒事项", type: .reminder)
        
        // 创建目标日历
        let targetCalendar = eventStore.createMockCalendar(title: "个人日历", type: .event)
        
        // 创建无截止日期提醒
        let reminder = eventStore.createMockReminder(
            title: "测试提醒",
            dueDate: nil,
            calendar: reminderList
        )
        
        // 处理提醒
        try await remindersManager.processReminder(reminder)
        
        // 验证提醒已被标记为完成
        XCTAssertTrue(reminder.isCompleted)
        XCTAssertTrue(eventStore.savedReminders.contains { saved in
            saved.reminder == reminder && saved.commit
        })
        
        // 验证事件已被创建，并且开始时间是当前时间
        XCTAssertEqual(eventStore.savedEvents.count, 1)
        let savedEvent = eventStore.savedEvents[0].event
        XCTAssertEqual(savedEvent.title, "测试提醒")
        XCTAssertEqual(savedEvent.calendar, targetCalendar)
        
        // 验证事件时间在当前时间附近（允许1分钟的误差）
        let now = Date()
        XCTAssertLessThanOrEqual(abs(savedEvent.startDate.timeIntervalSince(now)), 60)
    }
    
    func testProcessReminderWithNoTargetCalendar() async throws {
        // 创建提醒事项列表
        let reminderList = eventStore.createMockCalendar(title: "提醒事项", type: .reminder)
        
        // 创建过期提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let reminder = eventStore.createMockReminder(
            title: "过期提醒",
            dueDate: pastDate,
            calendar: reminderList
        )
        
        // 处理提醒应该抛出错误
        do {
            try await remindersManager.processReminder(reminder)
            XCTFail("应该抛出错误")
        } catch let error as CalendarError {
            XCTAssertEqual(error, .noCalendarsAvailable)
        }
        
        // 验证提醒没有被标记为完成
        XCTAssertFalse(reminder.isCompleted)
        XCTAssertFalse(eventStore.savedReminders.contains { saved in
            saved.reminder == reminder && saved.commit
        })
    }
} 