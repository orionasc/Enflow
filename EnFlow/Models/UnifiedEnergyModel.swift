
        import Foundation

/// Provides combined calculated + forecasted summaries.
@MainActor
final class UnifiedEnergyModel {
    static let shared = UnifiedEnergyModel()
    private init() {}

    private let calendar = Calendar.current
    private let summaryEngine = EnergySummaryEngine.shared
    private let forecastModel = EnergyForecastModel()
    private let cache = ForecastCache.shared

    /// Returns a DayEnergySummary blending calculated past energy with
    /// forecasted future energy when appropriate.
    func summary(for date: Date,
                 healthEvents: [HealthEvent],
                 calendarEvents: [CalendarEvent],
                 profile: UserProfile? = nil) -> DayEnergySummary {

        print("[UnifiedEnergyModel] mode: \(DataModeManager.shared.currentDataMode)")

        let summary = summaryEngine.summarize(day: date,
                                              healthEvents: healthEvents,
                                              calendarEvents: calendarEvents,
                                              profile: profile)

        guard let forecast = forecastModel.forecast(for: date,
                                                    health: healthEvents,
                                                    events: calendarEvents,
                                                    profile: profile) else {
            return summary
        }
        cache.saveForecast(forecast)

        var blended = summary.hourlyWaveform
        let now = Date()

        if calendar.isDateInToday(date) {
            let hr = calendar.component(.hour, from: now)
            for i in hr..<24 { blended[i] = forecast.values[i] }
        } else if date > calendar.startOfDay(for: now) {
            blended = forecast.values
        }

        // compute accuracy for past days if we have forecast stored
        if date < calendar.startOfDay(for: now), let prev = cache.forecast(for: date)?.values {
            let diffs = zip(prev, summary.hourlyWaveform).map { abs($0 - $1) }
            let acc = 1.0 - diffs.reduce(0, +) / Double(diffs.count)
            cache.saveAccuracy(acc, for: date)
        }

        let avgScore = blended.reduce(0, +) / Double(blended.count) * 100

        return DayEnergySummary(
            date: summary.date,
            overallEnergyScore: avgScore.rounded(),
            mentalEnergy: summary.mentalEnergy,
            physicalEnergy: summary.physicalEnergy,
            sleepEfficiency: summary.sleepEfficiency,
            coverageRatio: summary.coverageRatio,
            confidence: summary.confidence,
            warning: summary.warning,
            debugInfo: summary.debugInfo,
            hourlyWaveform: blended,
            topBoosters: summary.topBoosters,
            topDrainers: summary.topDrainers,
            explainers: summary.explainers

        )
    }
}
