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

        let highEnergyDays = feedback.filter(\.feltHighEnergy).map(\.date)
        let lowEnergyDays = feedback.filter { !$0.feltHighEnergy }.map(\.date)
        let stressDays = feedback.filter(\.feltStressed).map(\.date)
        let calmDays = feedback.filter { !$0.feltStressed }.map(\.date)
        let restDays = feedback.filter(\.feltWellRested).map(\.date)
        let tiredDays = feedback.filter { !$0.feltWellRested }.map(\.date)

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

        if !stressDays.isEmpty && !calmDays.isEmpty {
            let meetStress = stressDays.reduce(0) { $0 + metrics(for: $1).meetings }
            let meetCalm = calmDays.reduce(0) { $0 + metrics(for: $1).meetings }
            let avgStress = Double(meetStress) / Double(stressDays.count)
            let avgCalm = Double(meetCalm) / Double(calmDays.count)
            let diffM = avgStress - avgCalm
            if diffM > 0.5 {
                lines.append("Stressful days had about \(Int(round(diffM))) more meetings")
            }
        }

        let restGood = restDays.compactMap { metrics(for: $0).sleep }
        let restBad = tiredDays.compactMap { metrics(for: $0).sleep }
        let restDiff = diff(restGood, restBad)
        if abs(restDiff) > 10 {
            if restDiff > 0 {
                lines.append("Well rested days included \(Int(restDiff)) more mins of sleep")
            } else {
                lines.append("Tired days slept \(Int(-restDiff)) mins less")
            }
        }

        return lines
    }
}
