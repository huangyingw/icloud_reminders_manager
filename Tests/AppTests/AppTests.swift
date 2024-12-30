import XCTest
import EventKit
@testable import App
@testable import TestHelpers

final class AppTests: XCTestCase {
    var eventStore: MockEventStore!
    var app: App!
    var config: Config!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        
        // 创建测试配置
        config = Config(
            calendars: ["个人", "Reminders"],
            reminderLists: ["Reminders"],
            sync: Config.SyncConfig(interval: 300, autoCreate: false)
        )
    }
    
    override func tearDown() {
        eventStore = nil
        app = nil
        config = nil
        super.tearDown()
    }
    
    func testHistoricalEventHandling() async throws {
        // 创建模拟的 iCloud 源
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: EKSourceType.calDAV)
        
        // 创建测试日历
        let calendar = eventStore.createMockCalendar(for: EKEntityType.event, title: "个人", source: iCloudSource)
        
        // 创建一些历史事件
        let pastDates = [
            Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
            Calendar.current.date(byAdding: .day, value: -10, to: Date())!
        ]
        
        var createdEvents: [EKEvent] = []
        for (index, date) in pastDates.enumerated() {
            let event = eventStore.createMockEvent(
                title: "历史事件 \(index + 1)",
                startDate: date,
                calendar: calendar
            )
            createdEvents.append(event)
        }
        
        // 创建一个重复的事件（相同标题）
        let duplicateEvent = eventStore.createMockEvent(
            title: "历史事件 1",
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: Date())!,
            calendar: calendar
        )
        
        // 创建一个循环事件
        let recurringEvent = eventStore.createMockEvent(
            title: "循环事件",
            startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
            calendar: calendar
        )
        recurringEvent.recurrenceRules = [
            EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: nil
            )
        ]
        
        // 初始化 App
        app = try await App(eventStore: eventStore, config: config)
        
        // 执行同步
        try await app.syncRemindersToCalendar()
        
        // 验证结果
        let currentWeekStart = Calendar.current.date(from: 
            Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        
        // 获取所有当前事件
        let allEvents = eventStore.events(matching: eventStore.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [calendar]))
        
        // 验证历史事件已被移动到本周
        for event in allEvents where event.recurrenceRules?.isEmpty != false {
            guard let startDate = event.startDate else {
                XCTFail("事件没有开始时间")
                continue
            }
            XCTAssertGreaterThanOrEqual(startDate, currentWeekStart,
                "事件应该被移动到本周或之后: \(event.title ?? "")")
        }
        
        // 验证重复事件已被去重
        let eventTitles = allEvents.map { $0.title ?? "" }
        let uniqueTitles = Set(eventTitles)
        XCTAssertEqual(eventTitles.count, uniqueTitles.count,
            "不应该有重复的事件标题")
        
        // 验证循环事件保持不变
        XCTAssertTrue(allEvents.contains { event in
            event.title == "循环事件" && event.recurrenceRules?.isEmpty == false
        }, "循环事件应该保持不变")
    }
    
    func testEventDeduplication() async throws {
        // 创建模拟的 iCloud 源
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: EKSourceType.calDAV)
        
        // 创建测试日历
        let calendar = eventStore.createMockCalendar(for: EKEntityType.event, title: "个人", source: iCloudSource)
        
        // 创建多个具有相同标题的事件
        let eventTitle = "重复事件"
        var events: [EKEvent] = []
        
        for i in 0..<3 {
            let event = eventStore.createMockEvent(
                title: eventTitle,
                startDate: Calendar.current.date(byAdding: .day, value: -i * 5, to: Date())!,
                calendar: calendar
            )
            events.append(event)
        }
        
        // 初始化 App
        app = try await App(eventStore: eventStore, config: config)
        
        // 执行同步
        try await app.syncRemindersToCalendar()
        
        // 验证结果
        let remainingEvents = eventStore.events(matching: eventStore.predicateForEvents(
            withStart: Date.distantPast,
            end: Date.distantFuture,
            calendars: [calendar]))
        
        // 检查具有相同标题的事件是否只保留了一个
        let eventsWithSameTitle = remainingEvents.filter { $0.title == eventTitle }
        XCTAssertEqual(eventsWithSameTitle.count, 1,
            "应该只保留一个具有相同标题的事件")
        
        // 验证保留的是最新的事件
        if let remainingEvent = eventsWithSameTitle.first,
           let remainingStartDate = remainingEvent.startDate,
           let originalStartDate = events[0].startDate {
            XCTAssertEqual(remainingStartDate, originalStartDate,
                "应该保留最新的事件")
        } else {
            XCTFail("事件或开始时间为空")
        }
    }
} 