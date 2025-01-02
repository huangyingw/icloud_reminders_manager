import XCTest
import EventKit
@testable import Core

final class AppTests: XCTestCase {
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
    
    func testProcessExpiredEventsFromMultipleCalendars() async throws {
        // 创建模拟的 iCloud 源
        let iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建多个测试日历
        let calendar1 = eventStore.createMockCalendar(title: "工作", type: .event)
        calendar1.setValue(iCloudSource, forKey: "source")
        
        let calendar2 = eventStore.createMockCalendar(title: "学习", type: .event)
        calendar2.setValue(iCloudSource, forKey: "source")
        
        let calendar3 = eventStore.createMockCalendar(title: "目标", type: .event)
        calendar3.setValue(iCloudSource, forKey: "source")
        
        let personalCalendar = eventStore.createMockCalendar(title: "个人", type: .event)
        personalCalendar.setValue(iCloudSource, forKey: "source")
        
        // 在每个日历中创建过期事件
        let pastDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let event1 = eventStore.createMockEvent(title: "过期事件1", startDate: pastDate, calendar: calendar1)
        event1.endDate = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        
        let event2 = eventStore.createMockEvent(title: "过期事件2", startDate: pastDate, calendar: calendar2)
        event2.endDate = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        
        let event3 = eventStore.createMockEvent(title: "过期事件3", startDate: pastDate, calendar: calendar3)
        event3.endDate = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        
        // 运行测试
        try await app.run()
        
        // 验证目标日历中的事件数量
        let targetEvents = eventStore.getAllEvents().filter { $0.calendar.title == "个人" }
        XCTAssertEqual(targetEvents.count, 3, "目标日历应该包含所有过期事件")
        
        // 验证事件标题
        let eventTitles = Set(targetEvents.map { $0.title })
        XCTAssertTrue(eventTitles.contains("过期事件1"))
        XCTAssertTrue(eventTitles.contains("过期事件2"))
        XCTAssertTrue(eventTitles.contains("过期事件3"))
        
        // 验证原日历是否为空
        let calendar1Events = eventStore.getAllEvents().filter { $0.calendar == calendar1 }
        let calendar2Events = eventStore.getAllEvents().filter { $0.calendar == calendar2 }
        let calendar3Events = eventStore.getAllEvents().filter { $0.calendar == calendar3 }
        
        XCTAssertTrue(calendar1Events.isEmpty, "原日历1应该为空")
        XCTAssertTrue(calendar2Events.isEmpty, "原日历2应该为空")
        XCTAssertTrue(calendar3Events.isEmpty, "原日历3应该为空")
    }
} 