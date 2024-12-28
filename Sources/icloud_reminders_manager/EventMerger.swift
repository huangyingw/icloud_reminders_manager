import Foundation
import EventKit

class EventMerger {
    func findDuplicateEvents(_ events: [EKEvent]) -> [(EKEvent, [EKEvent])] {
        var duplicates: [(EKEvent, [EKEvent])] = []
        var processedEvents = Set<String>()
        
        for event in events {
            let eventId = event.eventIdentifier ?? ""
            if processedEvents.contains(eventId) {
                continue
            }
            
            var duplicateGroup: [EKEvent] = []
            for otherEvent in events {
                if event !== otherEvent && !processedEvents.contains(otherEvent.eventIdentifier ?? "") {
                    if isSimilarEvent(event, otherEvent) {
                        duplicateGroup.append(otherEvent)
                        processedEvents.insert(otherEvent.eventIdentifier ?? "")
                    }
                }
            }
            
            if !duplicateGroup.isEmpty {
                duplicates.append((event, duplicateGroup))
                processedEvents.insert(eventId)
            }
        }
        
        return duplicates
    }
    
    func mergeEvents(_ primary: EKEvent, with duplicates: [EKEvent]) -> EKEvent {
        let merged = primary
        var notes = Set<String>()
        var alarms = Set<EKAlarm>()
        
        // Add primary event notes and alarms
        if let primaryNotes = primary.notes {
            notes.insert(primaryNotes)
        }
        if let primaryAlarms = primary.alarms {
            alarms.formUnion(primaryAlarms)
        }
        
        // Add primary location if exists
        if let primaryLocation = primary.location {
            notes.insert("Primary location: \(primaryLocation)")
        }
        
        // Add primary URL if exists
        if let primaryURL = primary.url {
            notes.insert("Primary URL: \(primaryURL.absoluteString)")
        }
        
        // Add recurrence rule information if it exists
        var shortestInterval = Int.max
        var bestRule: EKRecurrenceRule? = nil
        
        if let primaryRules = primary.recurrenceRules {
            for rule in primaryRules {
                notes.insert(describeRecurrenceRule(rule, isOriginal: true))
                if rule.interval < shortestInterval {
                    shortestInterval = rule.interval
                    bestRule = rule
                }
            }
        }
        
        // Keep track of the earliest start time and latest end time
        guard let primaryStart = primary.startDate,
              let primaryEnd = primary.endDate else {
            return merged
        }
        
        var earliestStart = primaryStart
        var latestEnd = primaryEnd
        
        for duplicate in duplicates {
            // Add duplicate notes and alarms
            if let duplicateNotes = duplicate.notes {
                notes.insert(duplicateNotes)
            }
            if let duplicateAlarms = duplicate.alarms {
                alarms.formUnion(duplicateAlarms)
            }
            
            // Update start and end times
            if let duplicateStart = duplicate.startDate,
               let duplicateEnd = duplicate.endDate {
                if duplicateStart < earliestStart {
                    earliestStart = duplicateStart
                }
                if duplicateEnd > latestEnd {
                    latestEnd = duplicateEnd
                }
            }
            
            // Add duplicate recurrence rule information
            if let duplicateRules = duplicate.recurrenceRules {
                for rule in duplicateRules {
                    notes.insert(describeRecurrenceRule(rule, isOriginal: false))
                    if rule.interval < shortestInterval {
                        shortestInterval = rule.interval
                        bestRule = rule
                    }
                }
            }
            
            // Add location information if different
            if let duplicateLocation = duplicate.location,
               duplicateLocation != merged.location {
                notes.insert("Alternative location: \(duplicateLocation)")
            }
            
            // Add URL information if different
            if let duplicateURL = duplicate.url,
               duplicateURL != merged.url {
                if merged.url == nil {
                    merged.url = duplicateURL
                }
                notes.insert("Alternative URL: \(duplicateURL.absoluteString)")
            }
        }
        
        // Update merged event times
        merged.startDate = earliestStart
        merged.endDate = latestEnd
        
        // Update recurrence rules
        if let bestRule = bestRule {
            merged.recurrenceRules = [bestRule]
        }
        
        // Update merged event
        merged.notes = Array(notes).sorted().joined(separator: "\n")
        merged.alarms = Array(alarms)
        
        return merged
    }
    
    private func isSimilarEvent(_ event1: EKEvent, _ event2: EKEvent) -> Bool {
        // Check if titles are similar (exact match or Levenshtein distance <= 2)
        let title1 = event1.title?.lowercased() ?? ""
        let title2 = event2.title?.lowercased() ?? ""
        
        if title1 == title2 {
            return true
        }
        
        let distance = levenshteinDistance(title1, title2)
        if distance <= 2 {
            return true
        }
        
        return false
    }
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let m = s1.count
        let n = s2.count
        var matrix = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m {
            matrix[i][0] = i
        }
        
        for j in 0...n {
            matrix[0][j] = j
        }
        
        for i in 1...m {
            for j in 1...n {
                let s1Index = s1.index(s1.startIndex, offsetBy: i - 1)
                let s2Index = s2.index(s2.startIndex, offsetBy: j - 1)
                let cost = s1[s1Index] == s2[s2Index] ? 0 : 1
                
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }
        
        return matrix[m][n]
    }
    
    private func describeRecurrenceRule(_ rule: EKRecurrenceRule, isOriginal: Bool) -> String {
        var description = "Recurrence Rule (\(isOriginal ? "Original" : "Duplicate"))"
        description += "\nFrequency: \(frequencyToString(rule.frequency))"
        description += "\ninterval: \(rule.interval)"
        
        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                description += "\nEnds on: \(endDate)"
            } else {
                description += "\noccurrences: \(end.occurrenceCount)"
            }
        }
        
        return description
    }
    
    private func frequencyToString(_ frequency: EKRecurrenceFrequency) -> String {
        switch frequency {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        @unknown default:
            return "Unknown"
        }
    }
} 