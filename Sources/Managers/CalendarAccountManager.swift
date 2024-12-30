import Foundation
import EventKit

public class CalendarAccountManager {
    private let eventStore: EKEventStore
    private var enabledCalendars: Set<EKCalendar>
    private var enabledReminderLists: Set<EKCalendar>
    private var previouslyEnabledCalendars: Set<EKCalendar>
    private var previouslyEnabledReminderLists: Set<EKCalendar>
    
    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
        self.enabledCalendars = Set()
        self.enabledReminderLists = Set()
        self.previouslyEnabledCalendars = Set()
        self.previouslyEnabledReminderLists = Set()
        
        // 初始化时获取所有已启用的日历和提醒列表
        let allCalendars = eventStore.calendars(for: .event)
        let allReminderLists = eventStore.calendars(for: .reminder)
        
        print("发现 \(allCalendars.count) 个日历和 \(allReminderLists.count) 个提醒列表")
        
        self.enabledCalendars = Set(allCalendars)
        self.enabledReminderLists = Set(allReminderLists)
    }
    
    /// 获取 iCloud 日历账号
    public func getiCloudAccount() -> EKSource? {
        let sources = eventStore.sources
        print("发现 \(sources.count) 个日历源:")
        
        for source in sources {
            print("- 源: \(source.title), 类型: \(source.sourceType.rawValue)")
            let calendars = source.calendars(for: .reminder)
            print("  提醒列表数量: \(calendars.count)")
            for calendar in calendars {
                print("  - 提醒列表: \(calendar.title)")
            }
        }
        
        // 首先尝试找到包含提醒列表的 iCloud 源
        let iCloudSources = sources.filter { source in
            source.sourceType == .calDAV && source.title.lowercased().contains("icloud")
        }
        
        // 优先选择包含提醒列表的 iCloud 源
        for source in iCloudSources {
            if !source.calendars(for: .reminder).isEmpty {
                print("选择包含提醒列表的 iCloud 源: \(source.title)")
                return source
            }
        }
        
        // 如果没有找到包含提醒列表的 iCloud 源，返回第一个 iCloud 源
        if let firstiCloudSource = iCloudSources.first {
            print("选择第一个 iCloud 源: \(firstiCloudSource.title)")
            return firstiCloudSource
        }
        
        // 如果找不到 iCloud 源，尝试找到任何包含提醒列表的 CalDAV 源
        for source in sources where source.sourceType == .calDAV {
            if !source.calendars(for: .reminder).isEmpty {
                print("选择包含提醒列表的 CalDAV 源: \(source.title)")
                return source
            }
        }
        
        // 如果还是找不到，返回第一个 CalDAV 源
        return sources.first { source in
            source.sourceType == .calDAV
        }
    }
    
    /// 获取 Google 日历账号
    public func getGoogleAccount() -> EKSource? {
        return eventStore.sources.first { source in
            source.sourceType == .calDAV && source.title.lowercased().contains("google")
        }
    }
    
    /// 启用 iCloud 日历账号，同时禁用其他账号
    public func enableiCloudAccount() throws {
        guard let iCloudSource = getiCloudAccount() else {
            throw CalendarError.iCloudAccountNotFound
        }
        
        print("找到 iCloud 源: \(iCloudSource.title)")
        
        // 保存当前所有已启用的日历和提醒列表的状态
        previouslyEnabledCalendars = enabledCalendars
        previouslyEnabledReminderLists = enabledReminderLists
        
        // 获取所有日历和提醒列表
        let allCalendars = eventStore.calendars(for: .event)
        let allReminderLists = eventStore.calendars(for: .reminder)
        
        // 只启用 iCloud 账号的日历和提醒列表
        enabledCalendars = Set(allCalendars.filter { $0.source == iCloudSource })
        enabledReminderLists = Set(allReminderLists.filter { $0.source == iCloudSource })
        
        print("已启用 \(enabledCalendars.count) 个 iCloud 日历和 \(enabledReminderLists.count) 个 iCloud 提醒列表")
    }
    
    /// 恢复之前的账号状态
    public func disableiCloudAccount() throws {
        guard let _ = getiCloudAccount() else {
            throw CalendarError.iCloudAccountNotFound
        }
        
        // 恢复之前的状态
        enabledCalendars = previouslyEnabledCalendars
        enabledReminderLists = previouslyEnabledReminderLists
        
        print("已恢复 \(enabledCalendars.count) 个日历和 \(enabledReminderLists.count) 个提醒列表")
    }
    
    /// 获取启用的 iCloud 日历
    public func getEnabledCalendars() -> [EKCalendar] {
        return Array(enabledCalendars)
    }
    
    /// 获取启用的 iCloud 提醒列表
    public func getEnabledReminderLists() -> [EKCalendar] {
        return Array(enabledReminderLists)
    }
    
    /// 检查是否只有 iCloud 账号被启用
    public func verifyOnlyiCloudEnabled() -> Bool {
        guard let iCloudSource = getiCloudAccount() else { return false }
        
        // 检查所有启用的日历和提醒列表是否都属于 iCloud 账号
        let allEnabled = enabledCalendars.union(enabledReminderLists)
        return !allEnabled.isEmpty && allEnabled.allSatisfy { $0.source == iCloudSource }
    }
    
    /// 检查日历是否启用
    public func isCalendarEnabled(_ calendar: EKCalendar) -> Bool {
        switch calendar.allowedEntityTypes {
        case [.event]:
            return enabledCalendars.contains(calendar)
        case [.reminder]:
            return enabledReminderLists.contains(calendar)
        default:
            return false
        }
    }
}

public enum CalendarError: Error {
    case iCloudAccountNotFound
    case operationFailed
    case googleAccountStillEnabled
} 