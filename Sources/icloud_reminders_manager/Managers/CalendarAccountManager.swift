import EventKit

public class CalendarAccountManager {
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    /// 获取 iCloud 账号
    public func getiCloudAccount() -> EKSource? {
        return eventStore.sources.first { source in
            source.sourceType == .calDAV && source.title == "iCloud"
        }
    }
    
    /// 获取 Google 账号
    public func getGoogleAccount() -> EKSource? {
        return eventStore.sources.first { source in
            source.sourceType == .calDAV && source.title == "Google"
        }
    }
    
    /// 启用 iCloud 账号
    public func enableiCloudAccount() throws {
        guard let iCloudSource = getiCloudAccount() else {
            throw CalendarError.iCloudAccountNotFound
        }
        
        // 验证日历和提醒列表
        let calendars = eventStore.calendars(for: .event).filter { $0.source == iCloudSource }
        let reminderLists = eventStore.calendars(for: .reminder).filter { $0.source == iCloudSource }
        
        guard !calendars.isEmpty else {
            throw CalendarError.calendarNotFound
        }
        
        guard !reminderLists.isEmpty else {
            throw CalendarError.reminderListNotFound
        }
    }
    
    /// 获取所有日历
    public func getCalendars() -> [EKCalendar] {
        guard let iCloudSource = getiCloudAccount() else {
            return []
        }
        return eventStore.calendars(for: .event).filter { $0.source == iCloudSource }
    }
    
    /// 获取所有提醒列表
    public func getReminderLists() -> [EKCalendar] {
        guard let iCloudSource = getiCloudAccount() else {
            return []
        }
        return eventStore.calendars(for: .reminder).filter { $0.source == iCloudSource }
    }
} 