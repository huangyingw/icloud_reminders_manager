import XCTest
import EventKit
@testable import icloud_reminders_manager

final class ReminderManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var remindersManager: RemindersManager!
    var iCloudSource: EKSource!
    var googleSource: EKSource!
    
    override func setUp() {
        super.setUp()
        
        // 创建 Mock 事件存储
        eventStore = MockEventStore()
        
        // 创建 iCloud 源
        iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建 Google 源
        googleSource = eventStore.createMockSource(title: "Google", type: .calDAV)
        
        // 创建提醒管理器
        remindersManager = RemindersManager(eventStore: eventStore)
    }
    
    override func tearDown() {
        eventStore = nil
        remindersManager = nil
        iCloudSource = nil
        googleSource = nil
        super.tearDown()
    }
    
    func testGetReminders() async throws {
        // 创建提醒列表
        let list = eventStore.createMockCalendar(for: .reminder, title: "提醒事项", source: iCloudSource)
        
        // 创建测试提醒
        let reminder1 = eventStore.createMockReminder(title: "提醒1", calendar: list)
        let reminder2 = eventStore.createMockReminder(title: "提醒2", calendar: list)
        
        // 获取提醒
        let reminders = try await remindersManager.getReminders(from: list)
        
        // 验证结果
        XCTAssertEqual(reminders.count, 2)
        XCTAssertTrue(reminders.contains(reminder1))
        XCTAssertTrue(reminders.contains(reminder2))
    }
    
    func testGetReminderLists() {
        // 创建提醒列表
        let list1 = eventStore.createMockCalendar(for: .reminder, title: "提醒列表1", source: iCloudSource)
        let list2 = eventStore.createMockCalendar(for: .reminder, title: "提醒列表2", source: iCloudSource)
        
        // 获取提醒列表
        let lists = remindersManager.getReminderLists()
        
        // 验证结果
        XCTAssertEqual(lists.count, 2)
        XCTAssertTrue(lists.contains(list1))
        XCTAssertTrue(lists.contains(list2))
    }
    
    func testGetExpiredReminders() async throws {
        // 创建提醒列表
        let list = eventStore.createMockCalendar(for: .reminder, title: "提醒事项", source: iCloudSource)
        
        // 创建过期提醒
        let expiredReminder = eventStore.createMockReminder(
            title: "过期提醒",
            dueDate: Date().addingTimeInterval(-86400), // 昨天
            calendar: list
        )
        
        // 创建未过期提醒
        let activeReminder = eventStore.createMockReminder(
            title: "未过期提醒",
            dueDate: Date().addingTimeInterval(86400), // 明天
            calendar: list
        )
        
        // 获取过期提醒
        let expiredReminders = try await remindersManager.getExpiredReminders(from: list)
        
        // 验证结果
        XCTAssertEqual(expiredReminders.count, 1)
        XCTAssertTrue(expiredReminders.contains(expiredReminder))
        XCTAssertFalse(expiredReminders.contains(activeReminder))
    }
} 