import Foundation
import EventKit

public struct MergeConfiguration {
    let levenshteinThreshold: Int
    let timeThreshold: TimeInterval
    let preferredLocation: String?
    let preferredURL: URL?
    
    public init(
        levenshteinThreshold: Int = 3,
        timeThreshold: TimeInterval = 30 * 60,
        preferredLocation: String? = nil,
        preferredURL: URL? = nil
    ) {
        self.levenshteinThreshold = levenshteinThreshold
        self.timeThreshold = timeThreshold
        self.preferredLocation = preferredLocation
        self.preferredURL = preferredURL
    }
}

public class EventMerger {
    private let eventStore: EKEventStore
    
    public init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }
    
    public func findDuplicateEvents(_ events: [EKEvent]) -> [[EKEvent]] {
        var duplicates: [[EKEvent]] = []
        var processedEvents = Set<EKEvent>()
        
        for event in events {
            if processedEvents.contains(event) { continue }
            
            var group = [event]
            for otherEvent in events {
                if otherEvent === event || processedEvents.contains(otherEvent) { continue }
                
                if areSimilarEvents(event, otherEvent) {
                    group.append(otherEvent)
                    processedEvents.insert(otherEvent)
                }
            }
            
            if group.count > 1 {
                duplicates.append(group)
            }
            processedEvents.insert(event)
        }
        
        return duplicates
    }
    
    public func mergeEvents(_ events: [EKEvent], config: MergeConfiguration = MergeConfiguration()) throws -> EKEvent {
        guard let primaryEvent = events.first else {
            throw NSError(domain: "EventMerger", code: -1, userInfo: [NSLocalizedDescriptionKey: "No events to merge"])
        }
        
        let mergedEvent = EKEvent(eventStore: eventStore)
        mergedEvent.title = primaryEvent.title
        mergedEvent.startDate = primaryEvent.startDate
        mergedEvent.endDate = events.map { $0.endDate }.max() ?? primaryEvent.endDate
        mergedEvent.calendar = primaryEvent.calendar
        
        // Merge notes
        var notes = [String]()
        for event in events {
            if let eventNotes = event.notes {
                notes.append(eventNotes)
            }
        }
        if !notes.isEmpty {
            mergedEvent.notes = notes.joined(separator: "\n\n")
        }
        
        // Merge URL
        if let preferredURL = config.preferredURL {
            mergedEvent.url = preferredURL
            if let primaryURL = primaryEvent.url, primaryURL != preferredURL {
                mergedEvent.notes = (mergedEvent.notes ?? "") + "\nAlternative URL: \(primaryURL.absoluteString)"
            }
        } else {
            mergedEvent.url = primaryEvent.url
            for event in events.dropFirst() {
                if let eventURL = event.url, eventURL != mergedEvent.url {
                    mergedEvent.notes = (mergedEvent.notes ?? "") + "\nAlternative URL: \(eventURL.absoluteString)"
                }
            }
        }
        
        // Merge location
        if let preferredLocation = config.preferredLocation {
            mergedEvent.location = preferredLocation
            if let primaryLocation = primaryEvent.location, primaryLocation != preferredLocation {
                mergedEvent.notes = (mergedEvent.notes ?? "") + "\nAlternative location: \(primaryLocation)"
            }
        } else {
            mergedEvent.location = primaryEvent.location
            for event in events.dropFirst() {
                if let eventLocation = event.location, eventLocation != mergedEvent.location {
                    mergedEvent.notes = (mergedEvent.notes ?? "") + "\nAlternative location: \(eventLocation)"
                }
            }
        }
        
        // Merge alarms
        var alarms = Set<EKAlarm>()
        for event in events {
            if let eventAlarms = event.alarms {
                alarms.formUnion(eventAlarms)
            }
        }
        mergedEvent.alarms = Array(alarms)
        
        // Merge recurrence rules
        if let primaryRule = primaryEvent.recurrenceRules?.first {
            mergedEvent.recurrenceRules = [primaryRule]
        }
        
        try eventStore.save(mergedEvent, span: .thisEvent, commit: true)
        return mergedEvent
    }
    
    private func areSimilarEvents(_ event1: EKEvent, _ event2: EKEvent) -> Bool {
        // Check titles
        let title1 = event1.title ?? ""
        let title2 = event2.title ?? ""
        let titleDistance = levenshteinDistance(title1, title2)
        
        // Check times
        let timeDistance = abs(event1.startDate.timeIntervalSince(event2.startDate))
        
        return titleDistance <= 3 && timeDistance <= 30 * 60
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = Array(repeating: 0, count: s2.count + 1)
        var last = Array(0...s2.count)
        
        for (i, c1) in s1.enumerated() {
            var cur = [i + 1] + empty
            for (j, c2) in s2.enumerated() {
                cur[j + 1] = c1 == c2 ? last[j] : min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }
        return last[s2.count]
    }
} 