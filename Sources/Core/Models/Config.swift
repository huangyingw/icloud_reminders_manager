import Foundation

public struct Config: Codable {
    public let targetCalendarName: String
    
    public init(targetCalendarName: String) {
        self.targetCalendarName = targetCalendarName
    }
    
    public static func load() throws -> Config {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("icloud_reminders_manager")
            .appendingPathComponent("config.json")
        
        let data = try Data(contentsOf: configURL)
        return try JSONDecoder().decode(Config.self, from: data)
    }
    
    public func save() throws {
        let configURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config")
            .appendingPathComponent("icloud_reminders_manager")
            .appendingPathComponent("config.json")
        
        // 创建目录
        try FileManager.default.createDirectory(
            at: configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        
        // 保存配置
        let data = try JSONEncoder().encode(self)
        try data.write(to: configURL)
    }
} 