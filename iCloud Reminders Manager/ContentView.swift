import SwiftUI
import EventKit

struct ContentView: View {
    @State private var eventStore = EKEventStore()
    @State private var isAuthorized = false
    @State private var message = ""
    
    var body: some View {
        VStack {
            Text(message)
                .padding()
            
            if !isAuthorized {
                Button("请求访问权限") {
                    requestAccess()
                }
            } else {
                Button("处理提醒") {
                    Task {
                        await processReminders()
                    }
                }
            }
        }
        .padding()
    }
    
    private func requestAccess() {
        Task {
            do {
                let calendarAccess = try await eventStore.requestAccess(to: .event)
                let reminderAccess = try await eventStore.requestAccess(to: .reminder)
                
                await MainActor.run {
                    isAuthorized = calendarAccess && reminderAccess
                    message = isAuthorized ? "已获得访问权限" : "无法获得访问权限"
                }
            } catch {
                await MainActor.run {
                    message = "请求访问权限时出错: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func processReminders() async {
        do {
            let remindersManager = RemindersManager(eventStore: eventStore)
            let lists = remindersManager.getReminderLists()
            
            guard !lists.isEmpty else {
                await MainActor.run {
                    message = "未找到任何提醒列表"
                }
                return
            }
            
            var expiredCount = 0
            for list in lists {
                let expiredReminders = try await remindersManager.getExpiredReminders(from: list)
                expiredCount += expiredReminders.count
            }
            
            await MainActor.run {
                message = "找到 \(expiredCount) 个过期提醒"
            }
        } catch {
            await MainActor.run {
                message = "处理提醒时出错: \(error.localizedDescription)"
            }
        }
    }
}

#Preview {
    ContentView()
} 