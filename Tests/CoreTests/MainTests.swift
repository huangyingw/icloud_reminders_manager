import XCTest
import EventKit
@testable import Core

final class MainTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: FileLogger!
    var app: App!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        config = Config(
            calendar: CalendarConfig(targetCalendarName: "个人"),
            reminder: ReminderConfig(listNames: ["提醒事项"])
        )
        logger = FileLogger(label: "test.logger")
        app = App(config: config, eventStore: eventStore, logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        logger = nil
        app = nil
        super.tearDown()
    }
    
    func testProcessExpiredReminders() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "提醒事项", type: .reminder)
        let targetCalendar = eventStore.createMockCalendar(title: "个人", type: .event)
        
        // 创建过期提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let reminder = eventStore.createMockReminder(title: "过期提醒", dueDate: pastDate, calendar: sourceCalendar)
        
        // 运行测试
        try await app.run()
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar == targetCalendar }
        XCTAssertEqual(events.count, 1, "应该创建一个新事件")
        XCTAssertEqual(events[0].title, "过期提醒", "事件标题应该与提醒相同")
        
        // 验证提醒是否被删除
        let predicate = eventStore.predicateForReminders(in: eventStore.calendars(for: .reminder))
        var reminders: [EKReminder] = []
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            _ = eventStore.fetchReminders(matching: predicate) { fetchedReminders in
                if let fetchedReminders = fetchedReminders {
                    reminders = fetchedReminders
                }
                continuation.resume()
            }
        }
        XCTAssertTrue(reminders.isEmpty, "提醒应该被删除")
    }
} 