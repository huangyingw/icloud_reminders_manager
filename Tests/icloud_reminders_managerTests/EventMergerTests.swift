import XCTest
import EventKit
@testable import Managers

final class EventMergerTests: XCTestCase {
    var eventStore: MockEventStore!
    var defaultCalendar: EKCalendar!
    
    override func setUpWithError() throws {
        eventStore = MockEventStore()
        
        // 创建模拟的 iCloud 源
        let mockSource = eventStore.createMockSource(title: "iCloud", type: .calDAV)
        defaultCalendar = eventStore.createMockCalendar(for: .event)
        defaultCalendar.source = mockSource
    }
    
    override func tearDownWithError() throws {
        eventStore = nil
        defaultCalendar = nil
    }
    
    func testMergeDuplicateEvents() async throws {
        // 创建重复的事件
        let event1 = eventStore.createMockEvent()
        event1.title = "Team Meeting"
        event1.startDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        event1.endDate = Calendar.current.date(byAdding: .hour, value: 1, to: event1.startDate)!
        event1.calendar = defaultCalendar
        try eventStore.save(event1, span: .thisEvent, commit: true)
        
        let event2 = eventStore.createMockEvent()
        event2.title = "Team Meeting"
        event2.startDate = event1.startDate
        event2.endDate = event1.endDate
        event2.calendar = defaultCalendar
        try eventStore.save(event2, span: .thisEvent, commit: true)
        
        // 合并重复事件
        let mergedEvents = try await eventStore.mergeDuplicateEvents()
        
        // 验证结果
        XCTAssertEqual(mergedEvents.count, 1)
        XCTAssertEqual(mergedEvents[0].title, "Team Meeting")
        XCTAssertEqual(mergedEvents[0].startDate, event1.startDate)
        XCTAssertEqual(mergedEvents[0].endDate, event1.endDate)
        
        // 清理
        try eventStore.remove(event1, span: .thisEvent, commit: true)
    }
    
    func testMergeDuplicateEventsError() async {
        // 设置错误标志
        eventStore.shouldThrowError = true
        
        // 验证错误处理
        do {
            _ = try await eventStore.mergeDuplicateEvents()
            XCTFail("Expected error to be thrown")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, "MockError")
            XCTAssertEqual(error.code, -1)
        }
    }
} 