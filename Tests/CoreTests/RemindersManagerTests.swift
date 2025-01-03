import XCTest
import EventKit
@testable import Core

final class RemindersManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: FileLogger!
    var remindersManager: RemindersManager!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        logger = FileLogger(label: "test")
        config = Config(calendar: CalendarConfig(targetCalendarName: "Test Calendar"),
                       reminder: ReminderConfig(listNames: ["Test List"]))
        remindersManager = RemindersManager(config: config, eventStore: eventStore, logger: logger)
        
        // 创建目标日历
        _ = eventStore.createMockCalendar(title: "Test Calendar", type: .event)
    }
    
    override func tearDown() {
        eventStore.clearMocks()
        eventStore = nil
        config = nil
        logger = nil
        remindersManager = nil
        super.tearDown()
    }
    
    func testProcessExpiredReminders() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "Test List", type: .reminder)
        let targetCalendar = try getTargetCalendar()
        
        // 创建过期提醒
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        _ = eventStore.createMockReminder(title: "过期提醒", dueDate: pastDate, calendar: sourceCalendar)
        
        // 处理过期提醒
        try await remindersManager.processExpiredReminders()
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertEqual(events.count, 1, "应该创建一个新事件")
        XCTAssertEqual(events[0].title, "过期提醒", "事件标题应该与提醒相同")
        
        // 验证原提醒是否被删除
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
        XCTAssertTrue(reminders.isEmpty, "原提醒应该被删除")
    }
    
    func testProcessNonExpiredReminders() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "Test List", type: .reminder)
        let targetCalendar = try getTargetCalendar()
        
        // 创建未过期提醒
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        _ = eventStore.createMockReminder(title: "未过期提醒", dueDate: futureDate, calendar: sourceCalendar)
        
        // 处理提醒
        try await remindersManager.processExpiredReminders()
        
        // 验证结果
        let events = eventStore.getAllEvents().filter { $0.calendar.calendarIdentifier == targetCalendar.calendarIdentifier }
        XCTAssertTrue(events.isEmpty, "不应该创建新事件")
        
        // 验证原提醒是否保留
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
        XCTAssertEqual(reminders.count, 1, "原提醒应该保留")
        XCTAssertEqual(reminders[0].title, "未过期提醒", "提醒标题应该保持不变")
    }
    
    private func getTargetCalendar() throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        guard let targetCalendar = calendars.first(where: { $0.title == config.calendar.targetCalendarName }) else {
            throw CalendarError.targetCalendarNotFound
        }
        return targetCalendar
    }
} 