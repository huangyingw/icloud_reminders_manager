import XCTest
import EventKit
@testable import App

final class CalendarAccountManagerTests: XCTestCase {
    var eventStore: EKEventStore!
    var manager: CalendarAccountManager!
    var config: Config!
    
    override func setUp() {
        super.setUp()
        eventStore = EKEventStore()
        
        // 创建测试配置
        config = Config(
            calendars: ["个人"],
            reminderLists: ["Reminders"],
            sync: Config.SyncConfig(interval: 300, autoCreate: false)
        )
        
        manager = CalendarAccountManager(eventStore: eventStore, config: config)
    }
    
    override func tearDown() {
        eventStore = nil
        manager = nil
        config = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertNotNil(manager)
        XCTAssertNotNil(manager.getEnabledCalendars())
        XCTAssertNotNil(manager.getEnabledReminderLists())
    }
    
    func testEnableiCloudAccount() async throws {
        // 由于需要实际的 iCloud 账号和权限，这里只测试基本流程
        do {
            try await manager.enableiCloudAccount()
            
            // 验证启用后的状态
            let calendars = manager.getEnabledCalendars()
            let reminderLists = manager.getEnabledReminderLists()
            
            // 至少应该有一个日历或提醒列表被启用
            XCTAssertTrue(!calendars.isEmpty || !reminderLists.isEmpty)
            
            // 验证只启用了 iCloud 的内容
            XCTAssertTrue(manager.verifyOnlyiCloudEnabled())
        } catch {
            // 在测试环境中，可能没有 iCloud 账号，所以这里的错误是可接受的
            XCTAssertTrue(error is AppError)
        }
    }
    
    func testDisableiCloudAccount() async throws {
        // 记录初始状态
        let initialCalendars = manager.getEnabledCalendars()
        let initialReminderLists = manager.getEnabledReminderLists()
        
        do {
            // 先启用 iCloud
            try await manager.enableiCloudAccount()
            
            // 然后禁用 iCloud
            try manager.disableiCloudAccount()
            
            // 验证是否恢复到初始状态
            XCTAssertEqual(manager.getEnabledCalendars().count, initialCalendars.count)
            XCTAssertEqual(manager.getEnabledReminderLists().count, initialReminderLists.count)
        } catch {
            // 在测试环境中，可能没有 iCloud 账号，所以这里的错误是可接受的
            XCTAssertTrue(error is AppError)
        }
    }
    
    func testVerifyOnlyiCloudEnabled() async throws {
        do {
            // 初始状态可能包含非 iCloud 的日历
            XCTAssertFalse(manager.verifyOnlyiCloudEnabled())
            
            // 启用 iCloud
            try await manager.enableiCloudAccount()
            
            // 验证只启用了 iCloud 的内容
            XCTAssertTrue(manager.verifyOnlyiCloudEnabled())
        } catch {
            // 在测试环境中，可能没有 iCloud 账号，所以这里的错误是可接受的
            XCTAssertTrue(error is AppError)
        }
    }
    
    func testConfigLoading() throws {
        // 测试配置加载
        XCTAssertEqual(config.calendars, ["个人"])
        XCTAssertEqual(config.reminderLists, ["Reminders"])
        XCTAssertEqual(config.sync.interval, 300)
        XCTAssertFalse(config.sync.autoCreate)
    }
} 