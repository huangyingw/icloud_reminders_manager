import XCTest
import EventKit
@testable import icloud_reminders_manager

final class CalendarManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var config: Config!
    var calendarManager: CalendarManager!
    var iCloudSource: EKSource!
    var googleSource: EKSource!
    
    override func setUp() {
        super.setUp()
        
        // 创建 Mock 事件存储
        eventStore = MockEventStore()
        
        // 创建 iCloud 源
        iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建 Google 源
        googleSource = eventStore.createMockSource(title: "Google", type: .calDAV)
        
        // 创建配置
        config = Config()
        
        // 创建日历管理器
        calendarManager = CalendarManager(eventStore: eventStore, config: config)
    }
    
    override func tearDown() {
        eventStore = nil
        config = nil
        calendarManager = nil
        iCloudSource = nil
        googleSource = nil
        super.tearDown()
    }
    
    func testGetSourceCalendars() {
        // 创建源日历
        let sourceCalendar1 = eventStore.createMockCalendar(for: .event, title: "工作", source: iCloudSource)
        let sourceCalendar2 = eventStore.createMockCalendar(for: .event, title: "家庭", source: iCloudSource)
        
        // 创建目标日历（不应该包含在源日历中）
        _ = eventStore.createMockCalendar(for: .event, title: "个人", source: iCloudSource)
        
        // 获取源日历
        let sourceCalendars = calendarManager.getSourceCalendars()
        
        // 验证结果
        XCTAssertEqual(sourceCalendars.count, 2)
        XCTAssertTrue(sourceCalendars.contains(sourceCalendar1))
        XCTAssertTrue(sourceCalendars.contains(sourceCalendar2))
    }
    
    func testGetTargetCalendar() {
        // 创建目标日历
        let targetCalendar = eventStore.createMockCalendar(for: .event, title: "个人", source: iCloudSource)
        
        // 获取目标日历
        let result = calendarManager.getTargetCalendar()
        
        // 验证结果
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.title, "个人")
        XCTAssertEqual(result?.source, iCloudSource)
    }
    
    func testMoveEventToTargetCalendar() throws {
        // 创建源日历和目标日历
        let sourceCalendar = eventStore.createMockCalendar(for: .event, title: "工作", source: iCloudSource)
        let targetCalendar = eventStore.createMockCalendar(for: .event, title: "个人", source: iCloudSource)
        
        // 创建测试事件
        let event = eventStore.createMockEvent(title: "测试事件", startDate: Date(), calendar: sourceCalendar)
        
        // 验证事件的初始日历
        XCTAssertEqual(event.calendar, sourceCalendar)
        
        // 尝试移动事件
        try calendarManager.moveEventToTargetCalendar(event, targetCalendar: targetCalendar)
        
        // 验证事件的目标日历已被设置
        XCTAssertEqual(event.calendar, targetCalendar)
        
        // 验证 save 方法被正确调用
        XCTAssertEqual(eventStore.savedEvents.count, 1)
        XCTAssertEqual(eventStore.savedEvents[0].event, event)
        XCTAssertEqual(eventStore.savedEvents[0].span, .thisEvent)
    }
} 