import Foundation
import EventKit

public class CalendarAccountManager {
    private let eventStore: EKEventStore
    private let config: Config
    private var enabledCalendars: Set<EKCalendar> = []
    private var enabledReminderLists: Set<EKCalendar> = []
    
    public init(eventStore: EKEventStore, config: Config) {
        self.eventStore = eventStore
        self.config = config
    }
    
    /// 启用 iCloud 账号
    public func enableiCloudAccount() throws {
        print("\n发现 \(getCalendars().count) 个日历和 \(getReminderLists().count) 个提醒列表")
        
        // 获取所有日历源
        let sources = eventStore.sources
        print("\n发现 \(sources.count) 个日历源:")
        for source in sources {
            print("- 源: \(source.title), 类型: \(source.sourceType.rawValue)")
            print("  提醒列表数量: \(source.calendars(for: .reminder).count)")
        }
        
        // 获取 iCloud 源
        guard let calendarSource = sources.first(where: { source in
            config.calendars.source.contains(source.title)
        }) else {
            print("\n未找到 iCloud 源")
            throw CalendarError.iCloudSourceNotFound
        }
        
        print("\n选择第一个 iCloud 源: \(calendarSource.title)")
        
        // 获取所有日历
        let allCalendars = eventStore.calendars(for: .event)
        let allReminderLists = eventStore.calendars(for: .reminder)
        
        // 启用 iCloud 日历
        if let iCloudSource = sources.first(where: { source in
            config.calendars.source.contains(source.title)
        }) {
            print("找到 iCloud 源: \(iCloudSource.title)")
            
            // 获取 iCloud 日历
            let iCloudCalendars = allCalendars.filter { $0.source == calendarSource }
            enabledCalendars = Set(iCloudCalendars.filter { calendar in
                !config.calendars.ignore.contains(calendar.title)
            })
            print("已启用 \(enabledCalendars.count) 个 iCloud 日历")
            
            // 获取 iCloud 提醒列表
            let iCloudReminderLists = allReminderLists.filter { $0.source == calendarSource }
            enabledReminderLists = Set(iCloudReminderLists.filter { list in
                config.reminders.lists.contains(list.title)
            })
            print("已启用 \(enabledReminderLists.count) 个 iCloud 提醒列表")
        }
        
        // 验证是否找到了目标日历
        if !enabledCalendars.contains(where: { $0.title == config.calendars.target }) {
            print("\n错误：未找到目标日历 '\(config.calendars.target)'")
            throw CalendarError.calendarNotFound
        }
        
        // 验证是否找到了所有配置的提醒列表
        let missingReminderLists = Set(config.reminders.lists).subtracting(enabledReminderLists.map { $0.title })
        if !missingReminderLists.isEmpty {
            print("\n警告：未找到以下提醒列表：")
            for list in missingReminderLists {
                print("- \(list)")
            }
            
            if config.reminders.autoCreate {
                print("\n正在创建缺失的提醒列表...")
                for list in missingReminderLists {
                    let newList = try createReminderList(title: list, source: calendarSource)
                    enabledReminderLists.insert(newList)
                    print("已创建提醒列表：\(list)")
                }
            } else {
                throw CalendarError.reminderListNotFound
            }
        }
    }
    
    /// 获取已启用的日历
    public func getEnabledCalendars() -> [EKCalendar] {
        return Array(enabledCalendars)
    }
    
    /// 获取已启用的提醒列表
    public func getEnabledReminderLists() -> [EKCalendar] {
        return Array(enabledReminderLists)
    }
    
    /// 获取所有日历
    public func getCalendars() -> [EKCalendar] {
        return eventStore.calendars(for: .event)
    }
    
    /// 获取所有提醒列表
    public func getReminderLists() -> [EKCalendar] {
        return eventStore.calendars(for: .reminder)
    }
    
    /// 创建新的提醒列表
    private func createReminderList(title: String, source: EKSource) throws -> EKCalendar {
        let list = EKCalendar(for: .reminder, eventStore: eventStore)
        list.title = title
        list.source = source
        try eventStore.saveCalendar(list, commit: true)
        return list
    }
} 