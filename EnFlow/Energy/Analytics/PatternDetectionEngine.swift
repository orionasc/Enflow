import Foundation

struct PatternDetectionEngine {
    private let calendar = Calendar.current

    func detectPatterns(events: [CalendarEvent], summaries: [DayEnergySummary]) -> [DetectedPattern] {
        guard !events.isEmpty && !summaries.isEmpty else { return [] }

        // Group events and summaries by day
        let eventDays = Dictionary(grouping: events) { calendar.startOfDay(for: $0.startTime) }
        let summaryByDay = Dictionary(uniqueKeysWithValues: summaries.map { (calendar.startOfDay(for: $0.date), $0) })

        // Candidate pattern checks
        let checks: [(String, ([CalendarEvent]) -> Bool)] = [
            ("3+ meetings after 1 PM", { evs in
                let count = evs.filter { isMeeting($0) && hour($0.startTime) >= 13 }.count
                return count >= 3
            }),
            ("Workout after 8 PM", { evs in
                evs.contains { isWorkout($0) && hour($0.startTime) >= 20 }
            })
        ]

        var results: [(DetectedPattern, Double)] = []
        let totalDays = summaries.count

        for (desc, matcher) in checks {
            var withScores: [Double] = []
            var withoutScores: [Double] = []

            for (day, summary) in summaryByDay {
                let evs = eventDays[day] ?? []
                if matcher(evs) {
                    withScores.append(summary.overallEnergyScore)
                } else {
                    withoutScores.append(summary.overallEnergyScore)
                }
            }

            guard withScores.count >= 2, !withoutScores.isEmpty else { continue }
            let avgWith = withScores.reduce(0, +) / Double(withScores.count)
            let avgWithout = withoutScores.reduce(0, +) / Double(withoutScores.count)
            let diff = avgWith - avgWithout
            // Only interested in drops
            guard diff < -2 else { continue }

            let conf = min(1.0, abs(diff) / 20.0 * Double(withScores.count) / Double(totalDays))
            let effect = String(format: "%.0f%% avg energy", diff)

            let pattern = DetectedPattern(pattern: desc,
                                          effect: effect,
                                          evidenceCount: withScores.count,
                                          confidence: conf)

            results.append((pattern, diff))
        }

        return results.sorted { $0.1 < $1.1 }.map { $0.0 }
    }

    // MARK: - Helpers
    private func hour(_ d: Date) -> Int {
        calendar.component(.hour, from: d)
    }

    private func isMeeting(_ ev: CalendarEvent) -> Bool {
        let lower = ev.eventTitle.lowercased()
        return lower.contains("meeting") || lower.contains("call")
    }

    private func isWorkout(_ ev: CalendarEvent) -> Bool {
        let lower = ev.eventTitle.lowercased()
        return lower.contains("gym") || lower.contains("run") || lower.contains("workout") || lower.contains("yoga")
    }
}

