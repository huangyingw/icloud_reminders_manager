import XCTest
import EventKit
@testable import Core

final class CalendarAccountManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var logger: FileLogger!
    var calendarManager: CalendarManager!
    var iCloudSource: EKSource!
    
    override func setUp() {
        super.setUp()
        eventStore = MockEventStore()
        config = Config(
            calendar: CalendarConfig(targetCalendarName: "个人"),
            reminder: ReminderConfig(listNames: ["提醒事项"])
        )
        logger = FileLogger(label: "test.logger")
        
        // 创建模拟的 iCloud 源
        iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        calendarManager = CalendarManager(config: config, eventStore: eventStore, logger: logger)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        logger = nil
        calendarManager = nil
        iCloudSource = nil
        super.tearDown()
    }
    
    func testGetICloudCalendars() {
        // 创建测试日历
        let calendar1 = eventStore.createMockCalendar(title: "工作", type: .event)
        calendar1.setValue(iCloudSource, forKey: "source")
        
        let calendar2 = eventStore.createMockCalendar(title: "个人", type: .event)
        calendar2.setValue(iCloudSource, forKey: "source")
        
        // 获取 iCloud 日历
        let iCloudCalendars = calendarManager.getICloudCalendars()
        
        // 验证结果
        XCTAssertEqual(iCloudCalendars.count, 2, "应该找到两个 iCloud 日历")
        XCTAssertTrue(iCloudCalendars.contains(where: { $0.title == "工作" }))
        XCTAssertTrue(iCloudCalendars.contains(where: { $0.title == "个人" }))
    }
    
    func testMoveEventToTargetCalendar() async throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(title: "工作", type: .event)
        sourceCalendar.setValue(iCloudSource, forKey: "source")
        
        let targetCalendar = eventStore.createMockCalendar(title: "个人", type: .event)
        targetCalendar.setValue(iCloudSource, forKey: "source")
        
        // 创建事件
        let event = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: sourceCalendar)
        
        // 移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证事件是否被移动到目标日历
        let targetEvents = eventStore.getAllEvents().filter { $0.calendar.title == "个人" }
        XCTAssertEqual(targetEvents.count, 1, "目标日历应该包含一个事件")
        XCTAssertEqual(targetEvents[0].title, "测试事件", "事件标题应该保持不变")
        
        // 验证源日历是否为空
        let sourceEvents = eventStore.getAllEvents().filter { $0.calendar == sourceCalendar }
        XCTAssertTrue(sourceEvents.isEmpty, "源日历应该为空")
    }
    
    func testMoveEventToTargetCalendarWhenAlreadyInTarget() async throws {
        // 创建目标日历
        let targetCalendar = eventStore.createMockCalendar(title: "个人", type: .event)
        targetCalendar.setValue(iCloudSource, forKey: "source")
        
        // 创建已在目标日历中的事件
        let event = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: targetCalendar)
        
        // 尝试移动事件到目标日历
        try await calendarManager.moveEventToTargetCalendar(event)
        
        // 验证事件仍然在目标日历中
        let targetEvents = eventStore.getAllEvents().filter { $0.calendar.title == "个人" }
        XCTAssertEqual(targetEvents.count, 1, "目标日历应该仍然包含一个事件")
        XCTAssertEqual(targetEvents[0].title, "测试事件", "事件标题应该保持不变")
    }
} 