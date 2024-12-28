import Foundation
import EventKit

class EventMerger {
    private let levenshteinThreshold: Int
    private let timeThreshold: TimeInterval // 30 minutes in seconds
    
    init(levenshteinThreshold: Int = 3, timeThreshold: TimeInterval = 30 * 60) {
        self.levenshteinThreshold = levenshteinThreshold
        self.timeThreshold = timeThreshold
    }
    
    func findDuplicateEvents(_ events: [EKEvent]) -> [(EKEvent, [EKEvent])] {
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
        // Check if titles are similar using Levenshtein distance
        let title1 = event1.title ?? ""
        let title2 = event2.title ?? ""
        let titleDistance = levenshteinDistance(title1, title2)
        guard titleDistance <= levenshteinThreshold else {
            return false
        }
        
        // Check if times are close enough
        let timeDistance = abs(event1.startDate.timeIntervalSince(event2.startDate))
        return timeDistance <= timeThreshold
    }
    
    func mergeEvents(_ primary: EKEvent, with duplicates: [EKEvent]) -> EKEvent {
        // Merge notes
        var mergedNotes = primary.notes ?? ""
        for event in duplicates {
            if let notes = event.notes, !notes.isEmpty {
                if !mergedNotes.isEmpty {
                    mergedNotes += "\n---\n"
                }
                mergedNotes += notes
            }
        }
        primary.notes = mergedNotes
        
        // Merge URLs
        var urls: [URL] = []
        if let primaryUrl = primary.url {
            urls.append(primaryUrl)
        }
        for event in duplicates {
            if let url = event.url, !urls.contains(url) {
                urls.append(url)
            }
        }
        
        if urls.count > 1 {
            // If multiple URLs exist, add them to notes
            let urlsString = urls.map { $0.absoluteString }.joined(separator: "\n")
            if !mergedNotes.isEmpty {
                mergedNotes += "\n\n"
            }
            mergedNotes += "URLs:\n" + urlsString
            primary.url = urls.first
        } else if !urls.isEmpty {
            primary.url = urls.first
        }
        
        // Merge alarms
        var alarms = Set(primary.alarms ?? [])
        for event in duplicates {
            if let eventAlarms = event.alarms {
                alarms.formUnion(eventAlarms)
            }
        }
        primary.alarms = Array(alarms)
        
        // Add attendee information to notes since we can't modify attendees directly
        var attendeeNotes = ""
        if let primaryAttendees = primary.attendees, !primaryAttendees.isEmpty {
            attendeeNotes = "Attendees:\n" + primaryAttendees.map { $0.name ?? "Unknown" }.joined(separator: "\n")
        }
        for event in duplicates {
            if let eventAttendees = event.attendees, !eventAttendees.isEmpty {
                if !attendeeNotes.isEmpty {
                    attendeeNotes += "\n"
                } else {
                    attendeeNotes = "Attendees:\n"
                }
                attendeeNotes += eventAttendees.map { $0.name ?? "Unknown" }.joined(separator: "\n")
            }
        }
        if !attendeeNotes.isEmpty {
            if !mergedNotes.isEmpty {
                mergedNotes += "\n\n"
            }
            mergedNotes += attendeeNotes
        }
        
        // Merge locations
        var locations: [String] = []
        if let primaryLocation = primary.location, !primaryLocation.isEmpty {
            locations.append(primaryLocation)
        }
        for event in duplicates {
            if let location = event.location, !location.isEmpty, !locations.contains(location) {
                locations.append(location)
            }
        }
        
        if locations.count > 1 {
            // If multiple locations exist, add them to notes
            let locationsString = locations.joined(separator: "\n")
            if !mergedNotes.isEmpty {
                mergedNotes += "\n\n"
            }
            mergedNotes += "Locations:\n" + locationsString
            primary.location = locations.first
        } else if !locations.isEmpty {
            primary.location = locations.first
        }
        
        // Keep the earliest start date and latest end date
        for event in duplicates {
            if event.startDate < primary.startDate {
                primary.startDate = event.startDate
            }
            if event.endDate > primary.endDate {
                primary.endDate = event.endDate
            }
        }
        
        // Update the final notes
        primary.notes = mergedNotes
        
        return primary
    }
    
    // MARK: - Helper Methods
    
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