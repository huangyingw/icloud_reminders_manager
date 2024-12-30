import XCTest
import EventKit
import Logging
@testable import icloud_reminders_manager

final class RemindersManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var remindersManager: RemindersManager!
    var defaultList: EKCalendar!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        
        // 创建模拟的 iCloud 源
        let mockSource = eventStore.createMockSource(title: "iCloud", type: EKSourceType.calDAV)
        defaultList = eventStore.createMockCalendar(for: EKEntityType.reminder, title: "Default List", source: mockSource)
        
        remindersManager = RemindersManager(eventStore: eventStore)
    }
    
    override func tearDown() {
        eventStore = nil
        remindersManager = nil
        defaultList = nil
        super.tearDown()
    }
    
    func testGetReminders() async throws {
        // 创建测试提醒
        let reminder = eventStore.createMockReminder(title: "Test Reminder", calendar: defaultList)
        try eventStore.save(reminder, span: .thisEvent)
        
        // 获取提醒
        let reminders = try await remindersManager.getReminders(from: defaultList)
        
        // 验证结果
        XCTAssertEqual(reminders.count, 1)
        XCTAssertEqual(reminders.first?.title, "Test Reminder")
        
        // 验证 save 方法被正确调用
        XCTAssertEqual(eventStore.savedReminders.count, 1)
        XCTAssertEqual(eventStore.savedReminders[0].reminder, reminder)
        XCTAssertEqual(eventStore.savedReminders[0].span, .thisEvent)
    }
    
    func testGetExpiredReminders() async throws {
        // 创建过期提醒
        let expiredReminder = eventStore.createMockReminder(
            title: "Expired Reminder",
            dueDate: Date().addingTimeInterval(-86400),
            calendar: defaultList
        )
        try eventStore.save(expiredReminder, span: .thisEvent)
        
        // 创建未过期提醒
        let activeReminder = eventStore.createMockReminder(
            title: "Active Reminder",
            dueDate: Date().addingTimeInterval(86400),
            calendar: defaultList
        )
        try eventStore.save(activeReminder, span: .thisEvent)
        
        // 获取过期提醒
        let expiredReminders = try await remindersManager.getExpiredReminders(from: defaultList)
        
        // 验证结果
        XCTAssertEqual(expiredReminders.count, 1)
        XCTAssertEqual(expiredReminders.first?.title, "Expired Reminder")
        
        // 验证 save 方法被正确调用
        XCTAssertEqual(eventStore.savedReminders.count, 2)
        XCTAssertTrue(eventStore.savedReminders.contains { $0.reminder === expiredReminder && $0.span == .thisEvent })
        XCTAssertTrue(eventStore.savedReminders.contains { $0.reminder === activeReminder && $0.span == .thisEvent })
    }
} 