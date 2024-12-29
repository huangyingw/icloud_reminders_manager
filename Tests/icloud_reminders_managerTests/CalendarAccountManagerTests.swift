import XCTest
import EventKit
@testable import Managers

final class CalendarAccountManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var accountManager: CalendarAccountManager!
    
    override func setUpWithError() throws {
        eventStore = MockEventStore()
        accountManager = CalendarAccountManager(eventStore: eventStore)
    }
    
    override func tearDownWithError() throws {
        eventStore = nil
        accountManager = nil
    }
    
    func testGetiCloudAccount() {
        // 创建模拟的 iCloud 源
        let mockSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        eventStore.setMockSources([mockSource])
        
        let iCloudAccount = accountManager.getiCloudAccount()
        XCTAssertNotNil(iCloudAccount)
        XCTAssertTrue(iCloudAccount?.title.lowercased().contains("icloud") == true)
        XCTAssertEqual(iCloudAccount?.sourceType, .calDAV)
    }
    
    func testGetGoogleAccount() {
        // 创建模拟的 Google 源
        let mockSource = eventStore.createMockSource(title: "Google", type: .calDAV)
        eventStore.setMockSources([mockSource])
        
        let googleAccount = accountManager.getGoogleAccount()
        XCTAssertNotNil(googleAccount)
        XCTAssertTrue(googleAccount?.title.lowercased().contains("google") == true)
        XCTAssertEqual(googleAccount?.sourceType, .calDAV)
    }
    
    func testEnableAndDisableiCloudAccount() throws {
        // 创建模拟的 iCloud 源和日历
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        let iCloudCalendar = eventStore.createMockCalendar(for: .event)
        iCloudCalendar.source = iCloudSource
        
        // 创建模拟的 Google 源和日历
        let googleSource = eventStore.createMockSource(title: "Google", type: .calDAV)
        let googleCalendar = eventStore.createMockCalendar(for: .event)
        googleCalendar.source = googleSource
        
        eventStore.setMockSources([iCloudSource, googleSource])
        
        // 重新创建 accountManager 以使用新的源
        accountManager = CalendarAccountManager(eventStore: eventStore)
        
        // 测试启用 iCloud 账号
        try accountManager.enableiCloudAccount()
        
        // 验证 iCloud 日历被启用，Google 日历被禁用
        XCTAssertTrue(accountManager.verifyOnlyiCloudEnabled())
        XCTAssertTrue(accountManager.isCalendarEnabled(iCloudCalendar))
        XCTAssertFalse(accountManager.isCalendarEnabled(googleCalendar))
        
        // 测试禁用 iCloud 账号
        try accountManager.disableiCloudAccount()
        
        // 验证所有日历都恢复到之前的状态
        XCTAssertTrue(accountManager.isCalendarEnabled(iCloudCalendar))
        XCTAssertTrue(accountManager.isCalendarEnabled(googleCalendar))
    }
    
    func testErrorHandling() {
        // 模拟没有 iCloud 账号的情况
        eventStore.setMockSources([])
        
        XCTAssertThrowsError(try accountManager.enableiCloudAccount()) { error in
            XCTAssertEqual(error as? CalendarError, .iCloudAccountNotFound)
        }
        
        XCTAssertThrowsError(try accountManager.disableiCloudAccount()) { error in
            XCTAssertEqual(error as? CalendarError, .iCloudAccountNotFound)
        }
    }
} 