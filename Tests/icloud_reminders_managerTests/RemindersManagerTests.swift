import XCTest
import EventKit
@testable import Managers

final class RemindersManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var remindersManager: RemindersManager!
    var defaultCalendar: EKCalendar!
    
    override func setUpWithError() throws {
        eventStore = MockEventStore()
        
        // 创建模拟的 iCloud 源
        let mockSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        defaultCalendar = eventStore.createMockCalendar(for: .reminder)
        defaultCalendar.source = mockSource
        
        remindersManager = RemindersManager(eventStore: eventStore)
    }
    
    override func tearDownWithError() throws {
        eventStore = nil
        remindersManager = nil
        defaultCalendar = nil
    }
    
    func testFetchIncompleteReminders() async throws {
        // 创建测试提醒
        let reminder1 = eventStore.createMockReminder()
        reminder1.title = "Test Reminder 1"
        reminder1.isCompleted = false
        
        let reminder2 = eventStore.createMockReminder()
        reminder2.title = "Test Reminder 2"
        reminder2.isCompleted = false
        
        let completedReminder = eventStore.createMockReminder()
        completedReminder.title = "Completed Reminder"
        completedReminder.isCompleted = true
        
        // 设置模拟响应
        eventStore.mockFetchRemindersResponse = [reminder1, reminder2]
        
        // 获取未完成的提醒
        let reminders = try await remindersManager.fetchIncompleteReminders()
        
        // 验证结果
        XCTAssertEqual(reminders.count, 2)
        XCTAssertEqual(reminders[0].title, "Test Reminder 1")
        XCTAssertEqual(reminders[1].title, "Test Reminder 2")
    }
    
    func testFetchIncompleteRemindersError() async {
        // 设置错误标志
        eventStore.shouldThrowError = true
        
        // 验证错误处理
        do {
            _ = try await remindersManager.fetchIncompleteReminders()
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "RemindersManager")
            XCTAssertEqual(error.code, -1)
        }
    }
} 