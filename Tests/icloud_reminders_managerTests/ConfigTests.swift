import XCTest
@testable import icloud_reminders_manager

final class ConfigTests: XCTestCase {
    func testConfig() {
        let config = Config()
        
        // 测试日历配置
        XCTAssertEqual(config.calendar.targetCalendarName, "个人")
        XCTAssertEqual(config.calendar.sourceCalendarNames, ["工作", "家庭"])
        
        // 测试提醒事项配置
        XCTAssertEqual(config.reminder.listNames, ["提醒事项", "待办事项"])
    }
} 