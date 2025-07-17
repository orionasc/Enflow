import Foundation

/// Provides day-level energy summaries with caching and simulated-data guards.
struct SummaryProvider {
    @MainActor
    static func summary(for date: Date,
                        healthEvents: [HealthEvent],
                        calendarEvents: [CalendarEvent],
                        profile: UserProfile? = nil) -> DayEnergySummary {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let isPast = date < startOfToday

        // Fallback when simulated data is active but no samples exist
        if DataModeManager.shared.isSimulated(), healthEvents.isEmpty {
            return DayEnergySummary(
                date: calendar.startOfDay(for: date),
                overallEnergyScore: 50,
                mentalEnergy: 50,
                physicalEnergy: 50,
                sleepEfficiency: 0,
                coverageRatio: 0,
                confidence: 0,
                warning: "Insufficient health data",
                debugInfo: "simulated fallback",
                hourlyWaveform: Array(repeating: 0.5, count: 24),
                topBoosters: [],
                topDrainers: [],
                explainers: []
            )
        }

        if isPast {
            // Use cached waveform if available
            if let wave = ForecastCache.shared.wave(for: date) {
                let base = EnergySummaryEngine.shared.summarize(day: date,
                                                                healthEvents: healthEvents,
                                                                calendarEvents: calendarEvents,
                                                                profile: profile)
                return withWave(wave, from: base)
            }
            let summary = EnergySummaryEngine.shared.summarize(day: date,
                                                               healthEvents: healthEvents,
                                                               calendarEvents: calendarEvents,
                                                               profile: profile)
            ForecastCache.shared.saveWave(summary.hourlyWaveform, for: date)
            return summary
        } else {
            var summary = UnifiedEnergyModel.shared.summary(for: date,
                                                            healthEvents: healthEvents,
                                                            calendarEvents: calendarEvents,
                                                            profile: profile)
            if summary.hourlyWaveform.count != 24 {
                summary = withWave(Array(repeating: 0.5, count: 24), from: summary)
            }
            return summary
        }
    }

    private static func withWave(_ wave: [Double], from base: DayEnergySummary) -> DayEnergySummary {
        DayEnergySummary(
            date: base.date,
            overallEnergyScore: base.overallEnergyScore,
            mentalEnergy: base.mentalEnergy,
            physicalEnergy: base.physicalEnergy,
            sleepEfficiency: base.sleepEfficiency,
            coverageRatio: base.coverageRatio,
            confidence: base.confidence,
            warning: base.warning,
            debugInfo: base.debugInfo,
            hourlyWaveform: wave,
            topBoosters: base.topBoosters,
            topDrainers: base.topDrainers,
            explainers: base.explainers
        )
    }
}
