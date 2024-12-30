import XCTest
@testable import icloud_reminders_manager

final class ConfigTests: XCTestCase {
    func testConfig() {
        let config = Config()
        XCTAssertEqual(config.personalCalendarName, "个人")
    }
} 