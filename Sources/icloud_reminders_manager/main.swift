import EventKit
import Logging

let logger = Logger(label: "main")

// 创建事件存储
let eventStore = EKEventStore()

// 请求访问日历和提醒事项的权限
let task: () async -> Void = {
    do {
        // 请求访问日历
        let calendarAccess = try await eventStore.requestAccess(to: .event)
        guard calendarAccess else {
            logger.error("无法访问日历")
            return
        }
        
        // 请求访问提醒事项
        let reminderAccess = try await eventStore.requestAccess(to: .reminder)
        guard reminderAccess else {
            logger.error("无法访问提醒事项")
            return
        }
        
        // 创建配置
        let config = Config()
        
        // 创建日历管理器
        let calendarManager = CalendarManager(eventStore: eventStore, config: config)
        
        // 创建提醒管理器
        let remindersManager = RemindersManager(eventStore: eventStore)
        
        // 创建事件合并器
        let eventMerger = EventMerger(eventStore: eventStore)
        
        // 创建账号管理器
        let accountManager = CalendarAccountManager(eventStore: eventStore)
        
        // 启用 iCloud 账号
        try accountManager.enableiCloudAccount()
        
        logger.info("初始化完成")
        
    } catch {
        logger.error("发生错误: \(error)")
    }
}

Task(operation: task)

// 等待任务完成
RunLoop.main.run() 