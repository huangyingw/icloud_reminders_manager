import AppKit
import EventKit

class AppDelegate: NSObject, NSApplicationDelegate {
    let eventStore = EKEventStore()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            do {
                // 请求日历访问权限
                let calendarAccess = try await eventStore.requestAccess(to: .event)
                print("日历访问权限：\(calendarAccess ? "已授权" : "已拒绝")")
                
                // 请求提醒访问权限
                let reminderAccess = try await eventStore.requestAccess(to: .reminder)
                print("提醒访问权限：\(reminderAccess ? "已授权" : "已拒绝")")
                
                // 退出应用程序
                NSApplication.shared.terminate(nil)
            } catch {
                print("请求权限时出错：\(error)")
                NSApplication.shared.terminate(nil)
            }
        }
    }
}

// 创建应用程序和代理
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 运行应用程序
app.run()
