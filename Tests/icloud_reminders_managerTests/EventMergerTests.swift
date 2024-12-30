import XCTest
import EventKit
@testable import icloud_reminders_manager

final class EventMergerTests: XCTestCase {
    var eventStore: MockEventStore!
    var eventMerger: EventMerger!
    var iCloudSource: EKSource!
    var calendar: EKCalendar!
    
    override func setUp() {
        super.setUp()
        
        // 创建 Mock 事件存储
        eventStore = MockEventStore()
        
        // 创建 iCloud 源
        iCloudSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        
        // 创建日历
        calendar = eventStore.createMockCalendar(for: .event, title: "测试日历", source: iCloudSource)
        
        // 创建事件合并器
        eventMerger = EventMerger(eventStore: eventStore)
    }
    
    override func tearDown() {
        eventStore = nil
        eventMerger = nil
        iCloudSource = nil
        calendar = nil
        super.tearDown()
    }
    
    func testMergeEvents() throws {
        // 创建测试事件
        let event1 = eventStore.createMockEvent(
            title: "测试事件",
            startDate: Date().addingTimeInterval(-3600), // 一小时前
            calendar: calendar
        )
        
        let event2 = eventStore.createMockEvent(
            title: "测试事件",
            startDate: Date(), // 现在
            calendar: calendar
        )
        
        let event3 = eventStore.createMockEvent(
            title: "测试事件",
            startDate: Date().addingTimeInterval(3600), // 一小时后
            calendar: calendar
        )
        
        // 合并事件
        let mergedEvent = try eventMerger.mergeEvents([event1, event2, event3], into: calendar)
        
        // 验证结果
        XCTAssertEqual(mergedEvent.title, "测试事件")
        XCTAssertEqual(mergedEvent.calendar, calendar)
        XCTAssertEqual(mergedEvent.startDate, event3.startDate) // 应该使用最新的时间
        
        // 验证 save 和 remove 方法被正确调用
        XCTAssertEqual(eventStore.savedEvents.count, 1)
        XCTAssertEqual(eventStore.savedEvents[0].event, mergedEvent)
        XCTAssertEqual(eventStore.savedEvents[0].span, .futureEvents)
        
        XCTAssertEqual(eventStore.removedEvents.count, 2)
        XCTAssertTrue(eventStore.removedEvents.contains { $0.event === event1 && $0.span == .futureEvents })
        XCTAssertTrue(eventStore.removedEvents.contains { $0.event === event2 && $0.span == .futureEvents })
    }
    
    func testMergeRecurringAndNormalEvents() throws {
        // 创建循环事件
        let recurringEvent = eventStore.createMockEvent(
            title: "循环事件",
            startDate: Date(),
            calendar: calendar
        )
        recurringEvent.recurrenceRules = [EKRecurrenceRule(
            recurrenceWith: .daily,
            interval: 1,
            end: nil
        )]
        
        // 创建普通事件
        let normalEvent = eventStore.createMockEvent(
            title: "循环事件",
            startDate: Date().addingTimeInterval(3600),
            calendar: calendar
        )
        
        // 合并事件
        let mergedEvent = try eventMerger.mergeEvents([recurringEvent, normalEvent], into: calendar)
        
        // 验证结果
        XCTAssertEqual(mergedEvent.title, "循环事件")
        XCTAssertEqual(mergedEvent.calendar, calendar)
        XCTAssertNotNil(mergedEvent.recurrenceRules) // 应该保留循环规则
        XCTAssertEqual(mergedEvent.startDate, normalEvent.startDate) // 应该使用最新的时间
        
        // 验证 save 和 remove 方法被正确调用
        XCTAssertEqual(eventStore.savedEvents.count, 1)
        XCTAssertEqual(eventStore.savedEvents[0].event, mergedEvent)
        XCTAssertEqual(eventStore.savedEvents[0].span, .futureEvents)
        
        XCTAssertEqual(eventStore.removedEvents.count, 1)
        XCTAssertTrue(eventStore.removedEvents.contains { $0.event === recurringEvent && $0.span == .futureEvents })
    }
} 