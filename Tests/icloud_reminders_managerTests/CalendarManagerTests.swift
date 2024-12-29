import XCTest
import EventKit
@testable import Managers

final class CalendarManagerTests: XCTestCase {
    var eventStore: MockEventStore!
    var calendarManager: CalendarManager!
    var defaultCalendar: EKCalendar!
    
    override func setUpWithError() throws {
        eventStore = MockEventStore()
        
        // 创建模拟的 iCloud 源
        let mockSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        defaultCalendar = eventStore.createMockCalendar(for: .event)
        defaultCalendar.source = mockSource
        
        calendarManager = CalendarManager(eventStore: eventStore)
    }
    
    override func tearDownWithError() throws {
        eventStore = nil
        calendarManager = nil
        defaultCalendar = nil
    }
    
    func testMoveExpiredEventToCurrentWeek() async throws {
        // 创建一个过期的事件
        let event = eventStore.createMockEvent()
        event.title = "Expired Event"
        event.startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        event.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event.startDate)!
        event.calendar = defaultCalendar
        try eventStore.save(event, span: .thisEvent, commit: true)
        
        // 移动事件到当前周
        try await calendarManager.moveExpiredEventToCurrentWeek(event)
        
        // 验证事件已被移动到当前周
        let currentWeekday = Calendar.current.component(.weekday, from: event.startDate)
        let targetWeekday = Calendar.current.component(.weekday, from: Date())
        XCTAssertEqual(currentWeekday, targetWeekday)
        
        // 验证事件的时间部分保持不变
        let originalHour = Calendar.current.component(.hour, from: event.startDate)
        let originalMinute = Calendar.current.component(.minute, from: event.startDate)
        let newHour = Calendar.current.component(.hour, from: event.startDate)
        let newMinute = Calendar.current.component(.minute, from: event.startDate)
        
        XCTAssertEqual(originalHour, newHour)
        XCTAssertEqual(originalMinute, newMinute)
        
        // 清理
        try eventStore.remove(event, span: .thisEvent, commit: true)
    }
    
    func testDeleteExpiredRecurringEvents() async throws {
        // 创建一个过期的循环事件
        let expiredEvent = eventStore.createMockEvent()
        expiredEvent.title = "Expired Recurring Event"
        expiredEvent.startDate = Calendar.current.date(byAdding: .month, value: -2, to: Date())!
        expiredEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: expiredEvent.startDate)!
        expiredEvent.calendar = defaultCalendar
        expiredEvent.recurrenceRules = [
            EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: .init(end: Calendar.current.date(byAdding: .month, value: -1, to: Date())!)
            )
        ]
        try eventStore.save(expiredEvent, span: .thisEvent, commit: true)
        
        // 创建一个未过期的循环事件
        let activeEvent = eventStore.createMockEvent()
        activeEvent.title = "Active Recurring Event"
        activeEvent.startDate = Date()
        activeEvent.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: activeEvent.startDate)!
        activeEvent.calendar = defaultCalendar
        activeEvent.recurrenceRules = [
            EKRecurrenceRule(
                recurrenceWith: .weekly,
                interval: 1,
                end: .init(end: Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
            )
        ]
        try eventStore.save(activeEvent, span: .thisEvent, commit: true)
        
        // 删除过期的循环事件
        try await calendarManager.deleteExpiredRecurringEvents()
        
        // 验证结果
        XCTAssertFalse(eventStore.mockEvents.contains(expiredEvent))
        XCTAssertTrue(eventStore.mockEvents.contains(activeEvent))
        
        // 清理
        try eventStore.remove(activeEvent, span: .thisEvent, commit: true)
    }
    
    func testMoveExpiredEventError() async {
        // 设置错误标志
        eventStore.shouldThrowError = true
        
        let event = eventStore.createMockEvent()
        
        // 验证错误处理
        do {
            try await calendarManager.moveExpiredEventToCurrentWeek(event)
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "MockError")
            XCTAssertEqual(error.code, -1)
        }
    }
} 