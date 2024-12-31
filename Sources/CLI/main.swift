import Core
import EventKit
import Logging

// 创建日志记录器
var logger = Logging.Logger(label: "com.example.icloud_reminders_manager")
logger.logLevel = .info

// 创建配置
let config = Config(targetCalendarName: "个人")

// 创建应用
let app = App(config: config, logger: logger)

do {
    // 运行应用
    try await app.run()
} catch {
    logger.error("运行失败: \(error)")
} 