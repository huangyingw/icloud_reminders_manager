import XCTest
@testable import Core

final class ConfigTests: XCTestCase {
    func testConfigInitialization() {
        let config = Config(
            calendar: CalendarConfig(targetCalendarName: "个人"),
            reminder: ReminderConfig(listNames: ["提醒事项"])
        )
        XCTAssertEqual(config.calendar.targetCalendarName, "个人")
        XCTAssertEqual(config.reminder.listNames, ["提醒事项"])
    }
    
    func testConfigCoding() throws {
        // 创建配置
        let config = Config(
            calendar: CalendarConfig(targetCalendarName: "个人"),
            reminder: ReminderConfig(listNames: ["提醒事项"])
        )
        
        // 编码
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        
        // 解码
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(Config.self, from: data)
        
        // 验证结果
        XCTAssertEqual(decodedConfig.calendar.targetCalendarName, "个人")
        XCTAssertEqual(decodedConfig.reminder.listNames, ["提醒事项"])
    }
    
    func testConfigSaveAndLoad() throws {
        // 创建配置
        let config = Config(
            calendar: CalendarConfig(targetCalendarName: "个人"),
            reminder: ReminderConfig(listNames: ["提醒事项"])
        )
        
        // 保存配置
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        try data.write(to: URL(fileURLWithPath: "config.json"))
        
        // 加载配置
        let loadedConfig = try Config.load()
        
        // 验证结果
        XCTAssertEqual(loadedConfig.calendar.targetCalendarName, "个人")
        XCTAssertEqual(loadedConfig.reminder.listNames, ["提醒事项"])
        
        // 清理
        try FileManager.default.removeItem(atPath: "config.json")
    }
} 