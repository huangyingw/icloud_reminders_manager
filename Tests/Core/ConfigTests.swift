import XCTest
@testable import Core

final class ConfigTests: XCTestCase {
    func testConfigInitialization() {
        let config = Config(targetCalendarName: "个人")
        XCTAssertEqual(config.targetCalendarName, "个人")
    }
    
    func testConfigCoding() throws {
        // 创建配置
        let config = Config(targetCalendarName: "个人")
        
        // 编码
        let encoder = JSONEncoder()
        let data = try encoder.encode(config)
        
        // 解码
        let decoder = JSONDecoder()
        let decodedConfig = try decoder.decode(Config.self, from: data)
        
        // 验证结果
        XCTAssertEqual(decodedConfig.targetCalendarName, "个人")
    }
    
    func testConfigSaveAndLoad() throws {
        // 创建配置
        let config = Config(targetCalendarName: "个人")
        
        // 保存配置
        try config.save()
        
        // 加载配置
        let loadedConfig = try Config.load()
        
        // 验证结果
        XCTAssertEqual(loadedConfig.targetCalendarName, "个人")
    }
} 