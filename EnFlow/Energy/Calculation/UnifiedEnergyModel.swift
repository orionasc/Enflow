
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

        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTarget = calendar.startOfDay(for: date)
        let isPast = startOfTarget < startOfToday

        if isPast && summary.warning != "Insufficient health data" {
            cache.saveWave(summary.hourlyWaveform, for: date)
        }

        if isPast && summary.warning == "Insufficient health data" {
            return summary
        }
        var blended = summary.hourlyWaveform

        // Past days use real summary only. No forecast blending.
        if isPast {
            if let prev = cache.forecast(for: date)?.values {
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

        guard let forecast = forecastModel.forecast(for: date,
                                                    health: healthEvents,
                                                    events: calendarEvents,
                                                    profile: profile) else {
            return summary
        }
        cache.saveForecast(forecast)

        // Ensure both arrays have 24 values before blending
        let waveCount = summary.hourlyWaveform.count
        let forecastCount = forecast.values.count
        let currentHour = calendar.component(.hour, from: now)
        if waveCount < 24 || forecastCount < 24 {
            print("[UnifiedEnergyModel] insufficient data: waveCount=\(waveCount), forecastCount=\(forecastCount), hour=\(currentHour)")
            return summary
        }

        if startOfTarget == startOfToday {
            let hr = calendar.component(.hour, from: now)
            let blendWidth = 3
            let end = min(23, hr + blendWidth)
            for i in hr..<24 {
                guard i < summary.hourlyWaveform.count,
                      i < forecast.values.count,
                      i < blended.count else { break }
                if i <= end {
                    let t = Double(i - hr) / Double(blendWidth)
                    blended[i] = (1 - t) * summary.hourlyWaveform[i] + t * forecast.values[i]
                } else {
                    blended[i] = forecast.values[i]
                }
            }
        } else if !isPast {
            blended = forecast.values
        }

        // compute accuracy for past days if we have forecast stored
        if isPast, let prev = cache.forecast(for: date)?.values {
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
