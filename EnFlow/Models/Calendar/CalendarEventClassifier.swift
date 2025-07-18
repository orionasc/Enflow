import Foundation

/// Enhanced rule-based classifier for calendar events.
struct CalendarEventClassifier {
    struct Result {
        let label: String        // Booster, Drainer, Neutral
        let confidence: Double   // 0.0 – 1.0
    }

    private let calendar = Calendar.current

    private let boosterKeywords: [String] = [
        "gym", "run", "walk", "yoga", "workout", "bike", "hike", "meditate", "therapy",
        "stretch", "nap", "break", "lunch", "outdoors", "social", "friend", "dance"
    ]

    private let drainerKeywords: [String] = [
        "meeting", "call", "sync", "1:1", "review", "status", "check-in", "standup",
        "stand-up", "zoom", "teams", "presentation", "interview", "deadline", "class",
        "lecture", "commute", "doctor", "appointment", "exam", "test"
    ]

    func classify(_ event: CalendarEvent) -> Result {
        let title = event.eventTitle.lowercased()
        let duration = event.endTime.timeIntervalSince(event.startTime)
        let hour = calendar.component(.hour, from: event.startTime)

        // Count keyword matches
        let boosterHits = boosterKeywords.filter { title.contains($0) }
        let drainerHits = drainerKeywords.filter { title.contains($0) }

        // Determine base label and confidence
        if !boosterHits.isEmpty {
            var score = 0.6 + 0.1 * Double(min(boosterHits.count, 3))
            if duration > 90 * 60 { score -= 0.2 } // long boosters = less effective
            if hour < 6 || hour > 21 { score -= 0.1 }
            return Result(label: "Booster", confidence: max(0.5, min(1.0, score)))
        }

        if !drainerHits.isEmpty {
            var score = 0.6 + 0.1 * Double(min(drainerHits.count, 3))
            if duration > 90 * 60 { score += 0.1 }
            if (13...17).contains(hour) { score += 0.1 } // afternoon drag
            return Result(label: "Drainer", confidence: max(0.5, min(1.0, score)))
        }

        // Duration-based fallback
        if duration >= 3 * 3600 {
            return Result(label: "Drainer", confidence: 0.55)
        }

        return Result(label: "Neutral", confidence: 0.5)
    }
}
