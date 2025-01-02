import Core
import EventKit
import Foundation

// 创建日志记录器
let logger = FileLogger(label: "com.example.icloud_reminders_manager")

// 加载配置
let config = try Config.load()

// 创建事件存储
let eventStore = EKEventStore()

// 创建应用
let app = App(config: config, eventStore: eventStore, logger: logger)

do {
    try await app.run()
} catch {
    logger.error("运行失败: \(error)")
    exit(1)
} 
