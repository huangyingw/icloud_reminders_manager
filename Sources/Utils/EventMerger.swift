import Foundation
import EventKit

public struct MergeConfiguration {
    let levenshteinThreshold: Int
    let timeThreshold: TimeInterval
    let shouldMergeNotes: Bool
    let shouldMergeURLs: Bool
    let shouldMergeAlarms: Bool
    let shouldMergeAttendees: Bool
    let shouldMergeLocations: Bool
    let shouldMergeRecurrenceRules: Bool
    
    public static let `default` = MergeConfiguration(
        levenshteinThreshold: 3,
        timeThreshold: 30 * 60,
        shouldMergeNotes: true,
        shouldMergeURLs: true,
        shouldMergeAlarms: true,
        shouldMergeAttendees: true,
        shouldMergeLocations: true,
        shouldMergeRecurrenceRules: true
    )
    
    public init(
        levenshteinThreshold: Int = 3,
        timeThreshold: TimeInterval = 30 * 60,
        shouldMergeNotes: Bool = true,
        shouldMergeURLs: Bool = true,
        shouldMergeAlarms: Bool = true,
        shouldMergeAttendees: Bool = true,
        shouldMergeLocations: Bool = true,
        shouldMergeRecurrenceRules: Bool = true
    ) {
        self.levenshteinThreshold = levenshteinThreshold
        self.timeThreshold = timeThreshold
        self.shouldMergeNotes = shouldMergeNotes
        self.shouldMergeURLs = shouldMergeURLs
        self.shouldMergeAlarms = shouldMergeAlarms
        self.shouldMergeAttendees = shouldMergeAttendees
        self.shouldMergeLocations = shouldMergeLocations
        self.shouldMergeRecurrenceRules = shouldMergeRecurrenceRules
    }
}

public class EventMerger {
    private let levenshteinThreshold: Int
    private let timeThreshold: TimeInterval
    private let config: MergeConfiguration
    
    public init(config: MergeConfiguration = .default) {
        self.config = config
        self.levenshteinThreshold = config.levenshteinThreshold
        self.timeThreshold = config.timeThreshold
    }
    
    public func findDuplicateEvents(_ events: [EKEvent]) -> [(EKEvent, [EKEvent])] {
        var duplicates: [(EKEvent, [EKEvent])] = []
        var processedEvents = Set<EKEvent>()
        
        for event in events {
            if processedEvents.contains(event) {
                continue
            }
            
            var duplicateGroup: [EKEvent] = []
            for otherEvent in events {
                if event !== otherEvent &&
                   !processedEvents.contains(otherEvent) &&
                   areSimilarEvents(event, otherEvent) {
                    duplicateGroup.append(otherEvent)
                    processedEvents.insert(otherEvent)
                }
            }
            
            if !duplicateGroup.isEmpty {
                duplicates.append((event, duplicateGroup))
                processedEvents.insert(event)
            }
        }
        
        return duplicates
    }
    
    private func areSimilarEvents(_ event1: EKEvent, _ event2: EKEvent) -> Bool {
        let title1 = event1.title ?? ""
        let title2 = event2.title ?? ""
        let titleDistance = levenshteinDistance(title1, title2)
        guard titleDistance <= levenshteinThreshold else {
            return false
        }
        
        let timeDistance = abs(event1.startDate.timeIntervalSince(event2.startDate))
        return timeDistance <= timeThreshold
    }
    
    public func mergeEventsWithConfig(_ primary: EKEvent, with duplicates: [EKEvent], config: MergeConfiguration? = nil) -> EKEvent {
        let mergeConfig = config ?? self.config
        let merged = primary
        
        if mergeConfig.shouldMergeNotes {
            merged.notes = mergeNotes(primary, with: duplicates)
        }
        
        if mergeConfig.shouldMergeURLs {
            mergeURLs(merged, with: duplicates)
        }
        
        if mergeConfig.shouldMergeAlarms {
            merged.alarms = mergeAlarms(primary, with: duplicates)
        }
        
        if mergeConfig.shouldMergeAttendees {
            mergeAttendees(merged, with: duplicates)
        }
        
        if mergeConfig.shouldMergeLocations {
            mergeLocations(merged, with: duplicates)
        }
        
        if mergeConfig.shouldMergeRecurrenceRules {
            mergeRecurrenceRules(merged, with: duplicates)
        }
        
        return merged
    }
    
    private func mergeNotes(_ primary: EKEvent, with duplicates: [EKEvent]) -> String {
        var mergedNotes = primary.notes ?? ""
        for event in duplicates {
            if let notes = event.notes, !notes.isEmpty {
                if !mergedNotes.isEmpty {
                    mergedNotes += "\n---\n"
                }
                mergedNotes += notes
            }
        }
        return mergedNotes
    }
    
    private func mergeURLs(_ merged: EKEvent, with duplicates: [EKEvent]) {
        var urls: [URL] = []
        if let primaryUrl = merged.url {
            urls.append(primaryUrl)
        }
        for event in duplicates {
            if let url = event.url, !urls.contains(url) {
                urls.append(url)
            }
        }
        
        if urls.count > 1 {
            let urlsString = urls.map { $0.absoluteString }.joined(separator: "\n")
            var notes = merged.notes ?? ""
            if !notes.isEmpty {
                notes += "\n\n"
            }
            notes += "URLs:\n" + urlsString
            merged.notes = notes
            merged.url = urls.first
        } else if !urls.isEmpty {
            merged.url = urls.first
        }
    }
    
    private func mergeAlarms(_ primary: EKEvent, with duplicates: [EKEvent]) -> [EKAlarm] {
        var alarms = Set(primary.alarms ?? [])
        for event in duplicates {
            if let eventAlarms = event.alarms {
                alarms.formUnion(eventAlarms)
            }
        }
        return Array(alarms)
    }
    
    private func mergeAttendees(_ merged: EKEvent, with duplicates: [EKEvent]) {
        var attendeeSet = Set<String>()
        
        if let primaryAttendees = merged.attendees {
            for attendee in primaryAttendees {
                if let name = attendee.name {
                    attendeeSet.insert(name)
                }
            }
        }
        
        for event in duplicates {
            if let eventAttendees = event.attendees {
                for attendee in eventAttendees {
                    if let name = attendee.name {
                        attendeeSet.insert(name)
                    }
                }
            }
        }
        
        if !attendeeSet.isEmpty {
            let attendeeNotes = "Attendees:\n" + attendeeSet.sorted().joined(separator: "\n")
            var notes = merged.notes ?? ""
            if !notes.isEmpty {
                notes += "\n\n"
            }
            notes += attendeeNotes
            merged.notes = notes
        }
    }
    
    private func mergeLocations(_ merged: EKEvent, with duplicates: [EKEvent]) {
        var locations: [String] = []
        if let primaryLocation = merged.location, !primaryLocation.isEmpty {
            locations.append(primaryLocation)
        }
        for event in duplicates {
            if let location = event.location, !location.isEmpty, !locations.contains(location) {
                locations.append(location)
            }
        }
        
        if locations.count > 1 {
            let locationsString = locations.joined(separator: "\n")
            var notes = merged.notes ?? ""
            if !notes.isEmpty {
                notes += "\n\n"
            }
            notes += "Locations:\n" + locationsString
            merged.notes = notes
            merged.location = locations.first
        } else if !locations.isEmpty {
            merged.location = locations.first
        }
    }
    
    private func mergeRecurrenceRules(_ merged: EKEvent, with duplicates: [EKEvent]) {
        var recurrenceInfo = "Original Recurrence Rules:\n"
        if let rules = merged.recurrenceRules, !rules.isEmpty {
            recurrenceInfo += describeRecurrenceRule(rules[0], eventTitle: merged.title ?? "Primary Event")
        }
        
        var bestRule = merged.recurrenceRules?.first
        for event in duplicates {
            if let rules = event.recurrenceRules, !rules.isEmpty {
                recurrenceInfo += "\n" + describeRecurrenceRule(rules[0], eventTitle: event.title ?? "Duplicate Event")
                if let rule = rules.first {
                    if bestRule == nil || rule.interval < bestRule!.interval {
                        bestRule = rule
                    }
                }
            }
        }
        
        merged.recurrenceRules = bestRule.map { [$0] }
        
        if !recurrenceInfo.isEmpty {
            var notes = merged.notes ?? ""
            if !notes.isEmpty {
                notes += "\n\n"
            }
            notes += recurrenceInfo
            merged.notes = notes
        }
    }
    
    private func describeRecurrenceRule(_ rule: EKRecurrenceRule, eventTitle: String) -> String {
        var description = "\(eventTitle):\n"
        description += "- Frequency: \(frequencyToString(rule.frequency))\n"
        description += "- Interval: \(rule.interval)"
        
        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                description += "\n- Ends: \(formatDate(endDate))"
            } else {
                description += "\n- Occurrences: \(end.occurrenceCount)"
            }
        } else {
            description += "\n- No end date"
        }
        
        return description
    }
    
    private func frequencyToString(_ frequency: EKRecurrenceFrequency) -> String {
        switch frequency {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        @unknown default: return "Unknown"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1 = Array(s1.lowercased())
        let s2 = Array(s2.lowercased())
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2.count + 1), count: s1.count + 1)
        
        for i in 0...s1.count {
            matrix[i][0] = i
        }
        
        for j in 0...s2.count {
            matrix[0][j] = j
        }
        
        for i in 1...s1.count {
            for j in 1...s2.count {
                if s1[i-1] == s2[j-1] {
                    matrix[i][j] = matrix[i-1][j-1]
                } else {
                    matrix[i][j] = min(
                        matrix[i-1][j] + 1,    // deletion
                        matrix[i][j-1] + 1,    // insertion
                        matrix[i-1][j-1] + 1   // substitution
                    )
                }
            }
        }
        
        return matrix[s1.count][s2.count]
    }
} 