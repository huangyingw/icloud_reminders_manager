import EventKit
import Logging

let logger = Logger(label: "main")

// 创建事件存储
let eventStore = EKEventStore()

// 请求访问日历和提醒事项的权限
let task: () async -> Void = {
    do {
        // 请求访问日历
        logger.info("正在请求日历访问权限...")
        let calendarAccess = try await eventStore.requestAccess(to: .event)
        guard calendarAccess else {
            logger.error("""
                无法访问日历。请按照以下步骤授予权限：
                1. 打开系统偏好设置
                2. 点击"隐私与安全性"
                3. 点击"日历"
                4. 确保本应用程序已被选中
                """)
            return
        }
        logger.info("已获得日历访问权限")
        
        // 请求访问提醒事项
        logger.info("正在请求提醒事项访问权限...")
        let reminderAccess = try await eventStore.requestAccess(to: .reminder)
        guard reminderAccess else {
            logger.error("""
                无法访问提醒事项。请按照以下步骤授予权限：
                1. 打开系统偏好设置
                2. 点击"隐私与安全性"
                3. 点击"提醒事项"
                4. 确保本应用程序已被选中
                """)
            return
        }
        logger.info("已获得提醒事项访问权限")
        
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
        logger.info("正在检查 iCloud 账号...")
        try accountManager.enableiCloudAccount()
        logger.info("iCloud 账号已启用")
        
        // 1. 处理日历事件
        logger.info("\n开始处理日历事件...")
        
        // 获取源日历
        let sourceCalendars = calendarManager.getSourceCalendars()
        guard !sourceCalendars.isEmpty else {
            logger.error("""
                未找到源日历。请确保：
                1. 已登录 iCloud 账号
                2. 已启用日历同步
                3. 在日历应用中有可用的日历
                """)
            return
        }
        logger.info("找到 \(sourceCalendars.count) 个源日历")
        
        // 获取目标日历
        guard let targetCalendar = calendarManager.getTargetCalendar() else {
            logger.error("""
                未找到目标日历。请确保：
                1. 已在配置文件中正确设置目标日历名称
                2. 目标日历已在日历应用中创建
                """)
            return
        }
        logger.info("找到目标日历: \(targetCalendar.title)")
        
        // 获取所有事件并按日历分组
        var calendarEvents: [EKCalendar: [EKEvent]] = [:]
        for calendar in sourceCalendars {
            let predicate = eventStore.predicateForEvents(withStart: Date.distantPast, end: Date(), calendars: [calendar])
            let events = eventStore.events(matching: predicate)
            if !events.isEmpty {
                calendarEvents[calendar] = events
            }
        }
        
        // 合并每个日历的事件
        for (calendar, events) in calendarEvents {
            logger.info("处理日历 '\(calendar.title)' 中的 \(events.count) 个事件")
            if !events.isEmpty {
                let mergedEvent = try eventMerger.mergeEvents(events, into: targetCalendar)
                logger.info("已将事件合并到 '\(mergedEvent.title ?? "无标题")'")
            }
        }
        
        // 2. 处理提醒事项
        logger.info("\n开始处理提醒事项...")
        
        // 获取所有提醒列表
        let reminderLists = remindersManager.getReminderLists()
        guard !reminderLists.isEmpty else {
            logger.error("""
                未找到任何提醒列表。请确保：
                1. 已登录 iCloud 账号
                2. 已启用提醒事项同步
                3. 在提醒事项应用中有可用的列表
                """)
            return
        }
        logger.info("找到 \(reminderLists.count) 个提醒列表")
        
        // 遍历每个提醒列表
        for list in reminderLists {
            logger.info("正在处理提醒列表: \(list.title)")
            
            // 获取过期提醒
            let expiredReminders = try await remindersManager.getExpiredReminders(from: list)
            if expiredReminders.isEmpty {
                logger.info("列表 '\(list.title)' 中没有过期提醒")
            } else {
                logger.info("列表 '\(list.title)' 中找到 \(expiredReminders.count) 个过期提醒:")
                for reminder in expiredReminders {
                    logger.info("- \(reminder.title ?? "无标题") (到期时间: \(reminder.dueDateComponents?.date?.description ?? "未知"))")
                }
            }
        }
        
        logger.info("\n所有处理完成")
        
    } catch {
        logger.error("""
            发生错误: \(error)
            
            可能的解决方案：
            1. 确保已登录 iCloud 账号
            2. 确保已启用日历和提醒事项同步
            3. 确保已授予应用程序访问日历和提醒事项的权限
            4. 检查网络连接
            """)
    }
}

Task(operation: task)

// 等待任务完成
RunLoop.main.run() 