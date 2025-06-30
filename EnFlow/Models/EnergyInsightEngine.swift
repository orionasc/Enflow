import Foundation

final class EnergyInsightEngine {
    static let shared = EnergyInsightEngine()
    private init() {}

    private let calendar = Calendar.current

    /// Basic correlations between daily feedback tags and health/calendar metrics.
    func feedbackInsights(feedback: [DailyFeedback],
                          health: [HealthEvent],
                          events: [CalendarEvent]) -> [String] {
        guard !feedback.isEmpty else { return [] }

        func metrics(for day: Date) -> (sleep: Double?, hrv: Double?, meetings: Int) {
            let h = health.first { calendar.isDate($0.date, inSameDayAs: day) }
            let sleep = h.map { $0.deepSleep + $0.remSleep }
            let hrv = h?.hrv
            let meetings = events.filter {
                calendar.isDate($0.startTime, inSameDayAs: day) &&
                $0.eventTitle.lowercased().contains("meeting")
            }.count
            return (sleep, hrv, meetings)
        }

        func diff(_ a: [Double], _ b: [Double]) -> Double {
            guard !a.isEmpty && !b.isEmpty else { return 0 }
            let av = a.reduce(0, +) / Double(a.count)
            let bv = b.reduce(0, +) / Double(b.count)
            return av - bv
        }

        let highEnergyDays = feedback.filter { $0.energyLevel == .high }.map(\.date)
        let lowEnergyDays = feedback.filter { $0.energyLevel == .low }.map(\.date)

        var lines: [String] = []

        let sleepHigh = highEnergyDays.compactMap { metrics(for: $0).sleep }
        let sleepLow = lowEnergyDays.compactMap { metrics(for: $0).sleep }
        let sleepDiff = diff(sleepHigh, sleepLow)
        if abs(sleepDiff) > 10 {
            if sleepDiff > 0 {
                lines.append("High energy days had \(Int(sleepDiff)) more mins of sleep")
            } else {
                lines.append("Low energy days slept \(Int(-sleepDiff)) mins less")
            }
        }

        let hrvHigh = highEnergyDays.compactMap { metrics(for: $0).hrv }
        let hrvLow = lowEnergyDays.compactMap { metrics(for: $0).hrv }
        let hrvDiff = diff(hrvHigh, hrvLow)
        if abs(hrvDiff) > 2 {
            if hrvDiff > 0 {
                lines.append("HRV was about \(Int(hrvDiff)) ms higher on high energy days")
            } else {
                lines.append("HRV dropped by \(Int(-hrvDiff)) ms on low energy days")
            }
        }

        // Additional insights could be added here for other feedback metrics

        return lines
    }
}
