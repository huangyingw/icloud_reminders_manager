import Foundation

public struct Config: Codable {
    public let calendar: CalendarConfig
    public let reminder: ReminderConfig
    
    public init(calendar: CalendarConfig, reminder: ReminderConfig) {
        self.calendar = calendar
        self.reminder = reminder
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendar = try container.decode(CalendarConfig.self, forKey: .calendar)
        reminder = try container.decode(ReminderConfig.self, forKey: .reminder)
    }
    
    private enum CodingKeys: String, CodingKey {
        case calendar
        case reminder
    }
    
    public static func load() throws -> Config {
        let configURL = URL(fileURLWithPath: "config.json")
        let data = try Data(contentsOf: configURL)
        let decoder = JSONDecoder()
        return try decoder.decode(Config.self, from: data)
    }
}

public struct CalendarConfig: Codable {
    public let targetCalendarName: String
    
    public init(targetCalendarName: String) {
        self.targetCalendarName = targetCalendarName
    }
    
    private enum CodingKeys: String, CodingKey {
        case targetCalendarName = "target_calendar_name"
    }
}

public struct ReminderConfig: Codable {
    public let listNames: [String]
    
    public init(listNames: [String]) {
        self.listNames = listNames
    }
    
    private enum CodingKeys: String, CodingKey {
        case listNames = "list_names"
    }
} 