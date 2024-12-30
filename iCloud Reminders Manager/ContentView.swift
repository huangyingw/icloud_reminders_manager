import SwiftUI
import EventKit

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section("日历") {
                    ForEach(viewModel.calendars, id: \.calendarIdentifier) { calendar in
                        HStack {
                            Text(calendar.title)
                            Spacer()
                            Text(calendar.source?.title ?? "未知")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("过期事件") {
                    if viewModel.isLoading {
                        ProgressView()
                    } else if viewModel.expiredEvents.isEmpty {
                        Text("没有过期事件")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.expiredEvents, id: \.eventIdentifier) { event in
                            VStack(alignment: .leading) {
                                Text(event.title ?? "无标题")
                                    .font(.headline)
                                Text("开始时间：\(viewModel.formatDate(event.startDate))")
                                    .font(.caption)
                                Text("结束时间：\(viewModel.formatDate(event.endDate))")
                                    .font(.caption)
                                Text("日历：\(event.calendar.title)")
                                    .font(.caption)
                                if let rules = event.recurrenceRules, !rules.isEmpty {
                                    Text("重复规则：\(viewModel.describeRecurrenceRules(rules))")
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("iCloud Reminders Manager")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            await viewModel.mergeExpiredEvents()
                        }
                    }) {
                        Label("合并过期事件", systemImage: "arrow.triangle.merge")
                    }
                    .disabled(viewModel.expiredEvents.isEmpty)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Task {
                            await viewModel.refresh()
                        }
                    }) {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }
            }
        }
        .task {
            await viewModel.requestAccess()
            await viewModel.refresh()
        }
    }
}

@MainActor
class ContentViewModel: ObservableObject {
    private let eventStore = EKEventStore()
    private let calendarManager: CalendarManager
    private let eventMerger: EventMerger
    
    @Published var calendars: [EKCalendar] = []
    @Published var expiredEvents: [EKEvent] = []
    @Published var isLoading = false
    
    init() {
        self.calendarManager = CalendarManager(eventStore: eventStore)
        self.eventMerger = EventMerger(eventStore: eventStore)
    }
    
    func requestAccess() async {
        do {
            _ = try await eventStore.requestAccess(to: .event)
            _ = try await eventStore.requestAccess(to: .reminder)
        } catch {
            print("Error requesting access: \(error)")
        }
    }
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        // 获取所有日历
        calendars = calendarManager.getCalendars()
        
        // 获取过期的事件
        let now = Date()
        let calendar = Calendar.current
        
        // 获取过去30天的日期范围
        let startDate = calendar.date(byAdding: .day, value: -30, to: now)!
        let endDate = calendar.date(byAdding: .day, value: -1, to: now)!
        
        // 创建谓词来查找过期的事件
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        expiredEvents = eventStore.events(matching: predicate)
    }
    
    func mergeExpiredEvents() async {
        do {
            try eventMerger.mergeEvents(expiredEvents)
            await refresh()
        } catch {
            print("Error merging events: \(error)")
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
    
    func describeRecurrenceRules(_ rules: [EKRecurrenceRule]) -> String {
        rules.map { rule in
            var description = ""
            
            switch rule.frequency {
            case .daily:
                description = "每天"
            case .weekly:
                description = "每周"
            case .monthly:
                description = "每月"
            case .yearly:
                description = "每年"
            @unknown default:
                description = "未知"
            }
            
            if rule.interval > 1 {
                description += "间隔\(rule.interval)"
            }
            
            if let end = rule.recurrenceEnd {
                if let endDate = end.endDate {
                    description += "，直到\(formatDate(endDate))"
                } else {
                    description += "，重复\(end.occurrenceCount)次"
                }
            }
            
            return description
        }.joined(separator: "; ")
    }
}

#Preview {
    ContentView()
} 