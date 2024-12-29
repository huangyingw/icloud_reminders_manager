import Foundation
import EventKit
import Core
import Managers

@main
class App {
    private let eventStore: EKEventStore
    private let accountManager: CalendarAccountManager
    
    init() {
        self.eventStore = EKEventStore()
        self.accountManager = CalendarAccountManager(eventStore: eventStore)
    }
    
    static func main() async throws {
        let app = App()
        try await app.run()
    }
    
    func run() async throws {
        // 请求日历和提醒的访问权限
        try await requestAccess()
        
        // 启用 iCloud 账号，同时禁用其他账号
        try accountManager.enableiCloudAccount()
        
        // 验证只有 iCloud 账号被启用
        guard accountManager.verifyOnlyiCloudEnabled() else {
            throw AppError.otherAccountsStillEnabled
        }
        
        defer {
            // 程序结束时恢复之前的账号状态
            try? accountManager.disableiCloudAccount()
        }
        
        // 执行主要的处理逻辑
        try await processRemindersAndEvents()
    }
    
    private func requestAccess() async throws {
        // 请求访问日历
        let calendarAccess = try await eventStore.requestAccess(to: .event)
        guard calendarAccess else {
            throw AppError.calendarAccessDenied
        }
        
        // 请求访问提醒
        let reminderAccess = try await eventStore.requestAccess(to: .reminder)
        guard reminderAccess else {
            throw AppError.reminderAccessDenied
        }
    }
    
    private func processRemindersAndEvents() async throws {
        // 获取启用的 iCloud 提醒列表和日历
        let reminderLists = accountManager.getEnabledReminderLists()
        let calendars = accountManager.getEnabledCalendars()
        
        // 确保有可用的提醒列表和日历
        guard !reminderLists.isEmpty else {
            throw AppError.noReminderListsAvailable
        }
        
        guard !calendars.isEmpty else {
            throw AppError.noCalendarsAvailable
        }
        
        // TODO: 在这里实现提醒和日历的处理逻辑
        // 1. 将提醒转化为日历事件
        // 2. 处理过期事件
        // 3. 检测并合并重复事件
    }
}

enum AppError: Error {
    case calendarAccessDenied
    case reminderAccessDenied
    case noReminderListsAvailable
    case noCalendarsAvailable
    case otherAccountsStillEnabled
} 