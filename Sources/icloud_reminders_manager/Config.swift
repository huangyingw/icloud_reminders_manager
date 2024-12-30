import Foundation

public struct Config: Codable {
    public let calendar: CalendarConfig
    public let reminder: ReminderConfig
    
    public struct CalendarConfig: Codable {
        public let targetCalendarName: String
        public let sourceCalendarNames: [String]
        
        private enum CodingKeys: String, CodingKey {
            case targetCalendarName = "target_calendar_name"
            case sourceCalendarNames = "source_calendar_names"
        }
    }
    
    public struct ReminderConfig: Codable {
        public let listNames: [String]
        
        private enum CodingKeys: String, CodingKey {
            case listNames = "list_names"
        }
    }
    
    public init() {
        let configURL = Bundle.module.url(forResource: "config", withExtension: "json")!
        let configData = try! Data(contentsOf: configURL)
        self = try! JSONDecoder().decode(Config.self, from: configData)
    }
} 