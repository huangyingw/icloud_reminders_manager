import Foundation

public struct Config: Codable {
    public struct CalendarConfig: Codable {
        public let source: [String]
        public let target: String
        public let ignore: [String]
        
        public init(source: [String], target: String, ignore: [String]) {
            self.source = source
            self.target = target
            self.ignore = ignore
        }
    }
    
    public struct ReminderConfig: Codable {
        public let lists: [String]
        public let autoCreate: Bool
        
        public init(lists: [String], autoCreate: Bool) {
            self.lists = lists
            self.autoCreate = autoCreate
        }
    }
    
    public struct SyncConfig: Codable {
        public let interval: Int
        public let autoMerge: Bool
        public let keepOriginal: Bool
        
        public init(interval: Int, autoMerge: Bool, keepOriginal: Bool) {
            self.interval = interval
            self.autoMerge = autoMerge
            self.keepOriginal = keepOriginal
        }
    }
    
    public let calendars: CalendarConfig
    public let reminders: ReminderConfig
    public let sync: SyncConfig
    
    public init(calendars: CalendarConfig, reminders: ReminderConfig, sync: SyncConfig) {
        self.calendars = calendars
        self.reminders = reminders
        self.sync = sync
    }
    
    public static func load() throws -> Config {
        let configPath = "config.json"
        let configURL = URL(fileURLWithPath: configPath)
        
        guard let configData = try? Data(contentsOf: configURL) else {
            // 如果配置文件不存在，返回默认配置
            return Config(
                calendars: CalendarConfig(
                    source: ["iCloud"],
                    target: "个人",
                    ignore: ["Birthdays", "Holidays"]
                ),
                reminders: ReminderConfig(
                    lists: ["提醒事项"],
                    autoCreate: true
                ),
                sync: SyncConfig(
                    interval: 300,
                    autoMerge: true,
                    keepOriginal: false
                )
            )
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(Config.self, from: configData)
    }
}

public enum ConfigError: Error {
    case fileNotFound
    case invalidFormat
}

public enum CalendarError: Error {
    case iCloudSourceNotFound
    case calendarNotFound
    case reminderListNotFound
} 