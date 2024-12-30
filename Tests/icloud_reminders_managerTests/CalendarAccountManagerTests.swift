import XCTest
import EventKit
@testable import icloud_reminders_manager

final class CalendarAccountManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var accountManager: CalendarAccountManager!
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
        
        // 创建账号管理器
        accountManager = CalendarAccountManager(eventStore: eventStore)
        
        // 创建 iCloud 日历和提醒列表
        _ = eventStore.createMockCalendar(for: .event, title: "iCloud Calendar", source: iCloudSource)
        _ = eventStore.createMockCalendar(for: .reminder, title: "iCloud Reminders", source: iCloudSource)
        
        // 创建 Google 日历
        _ = eventStore.createMockCalendar(for: .event, title: "Google Calendar", source: googleSource)
    }
    
    override func tearDown() {
        eventStore = nil
        accountManager = nil
        iCloudSource = nil
        googleSource = nil
        super.tearDown()
    }
    
    func testGetiCloudAccount() {
        // 获取 iCloud 账号
        let account = accountManager.getiCloudAccount()
        
        // 验证结果
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.title, "iCloud")
        XCTAssertEqual(account?.sourceType, .calDAV)
        
        // 验证日历和提醒列表
        let calendars = Array(account?.calendars(for: .event) ?? [])
        XCTAssertEqual(calendars.count, 1)
        XCTAssertEqual(calendars.first?.title, "iCloud Calendar")
        
        let reminderLists = Array(account?.calendars(for: .reminder) ?? [])
        XCTAssertEqual(reminderLists.count, 1)
        XCTAssertEqual(reminderLists.first?.title, "iCloud Reminders")
    }
    
    func testGetGoogleAccount() {
        // 获取 Google 账号
        let account = accountManager.getGoogleAccount()
        
        // 验证结果
        XCTAssertNotNil(account)
        XCTAssertEqual(account?.title, "Google")
        XCTAssertEqual(account?.sourceType, .calDAV)
        
        // 验证日历
        let calendars = Array(account?.calendars(for: .event) ?? [])
        XCTAssertEqual(calendars.count, 1)
        XCTAssertEqual(calendars.first?.title, "Google Calendar")
    }
    
    func testEnableiCloudAccount() throws {
        // 启用 iCloud 账号
        try accountManager.enableiCloudAccount()
        
        // 验证日历和提醒列表
        let calendars = accountManager.getCalendars()
        XCTAssertEqual(calendars.count, 1)
        XCTAssertEqual(calendars.first?.title, "iCloud Calendar")
        
        let reminderLists = accountManager.getReminderLists()
        XCTAssertEqual(reminderLists.count, 1)
        XCTAssertEqual(reminderLists.first?.title, "iCloud Reminders")
    }
} 