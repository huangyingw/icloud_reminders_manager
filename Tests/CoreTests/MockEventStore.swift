import Foundation
import EventKit

class MockEventStore: EKEventStore {
    private var mockCalendars: [EKCalendar] = []
    private var mockEvents: [EKEvent] = []
    private var mockSources: [EKSource] = []
    
    override var sources: [EKSource] {
        return mockSources
    }
    
    override func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        return mockCalendars
    }
    
    override func saveCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        mockCalendars.append(calendar)
    }
    
    override func removeCalendar(_ calendar: EKCalendar, commit: Bool) throws {
        mockCalendars.removeAll { $0 === calendar }
    }
    
    override func save(_ event: EKEvent, span: EKSpan) throws {
        mockEvents.append(event)
    }
    
    override func remove(_ event: EKEvent, span: EKSpan) throws {
        mockEvents.removeAll { $0 === event }
    }
    
    override func requestAccess(to entityType: EKEntityType) async throws -> Bool {
        return true
    }
    
    func addMockSource(_ source: EKSource) {
        mockSources.append(source)
    }
    
    func addMockCalendar(_ calendar: EKCalendar) {
        mockCalendars.append(calendar)
    }
    
    func addMockEvent(_ event: EKEvent) {
        mockEvents.append(event)
    }
    
    func clearMocks() {
        mockCalendars.removeAll()
        mockEvents.removeAll()
        mockSources.removeAll()
    }
} 