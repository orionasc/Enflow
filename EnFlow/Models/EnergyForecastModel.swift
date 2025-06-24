//  EnergyForecastModel.swift
//  EnFlow
//
//  PIVOT → Energy-only model   (2025-06-17)
//  • Eliminated predictedStress / predictedRecovery usage
//  • Added circadian-weighted, research-based base-energy formula
//  • Hourly waveform now starts flat; event deltas will be layered in a later patch

import Foundation
import Combine
import HealthKit

// MARK: - EnergyForecastModel ---------------------------------------------------
@MainActor
final class EnergyForecastModel: ObservableObject {

    // Published summaries (still produced by EnergySummaryEngine)
    @Published private(set) var dailySummaries: [DayEnergySummary] = []

    private let calendar = Calendar.current
    private let summaryEngine = EnergySummaryEngine.shared

    struct ForecastResult { let values: [Double]; let score: Double }
    struct ThreePartEnergy { let morning: Double; let afternoon: Double; let evening: Double }

    // MARK: Daily rebuild
    func rebuildSummaries(health: [HealthEvent], events: [CalendarEvent]) {
        let healthByDay = Dictionary(grouping: health,  by: { calendar.startOfDay(for: $0.date) })
        let eventsByDay = Dictionary(grouping: events,  by: { calendar.startOfDay(for: $0.startTime) })
        let keys = Set(healthByDay.keys).union(eventsByDay.keys)


        dailySummaries = keys.sorted().map { day in
            summaryEngine.summarize(day: day,
                                    healthEvents: healthByDay[day] ?? [],
                                    calendarEvents: eventsByDay[day] ?? [])
        }
    }

    // MARK: Single-day forecast (24×values + daily composite)
    func forecast(for date: Date,
                  health: [HealthEvent],
                  events: [CalendarEvent]) -> ForecastResult? {

        let hSample = health.first { calendar.isDate($0.date, inSameDayAs: date) }
        guard let baseWave = hourlyWaveform(baseHealth: hSample) else { return nil }
        let score = baseWave.reduce(0, +) / Double(baseWave.count) * 100.0
        return ForecastResult(values: baseWave, score: score)
    }

    // MARK: 3-part (morning / afternoon / evening)
    func threePartEnergy(for date: Date,
                         health: [HealthEvent],
                         events: [CalendarEvent]) -> ThreePartEnergy? {

        guard let wave = forecast(for: date, health: health, events: events)?.values else { return nil }
        func avg(_ s: ArraySlice<Double>) -> Double { s.reduce(0, +) / Double(s.count) * 100.0 }
        return ThreePartEnergy(morning:  avg(wave[0..<8]),
                               afternoon: avg(wave[8..<16]),
                               evening:   avg(wave[16..<24]))
    }

    // MARK: Core waveform builder ------------------------------------------------
    private func hourlyWaveform(baseHealth h: HealthEvent?) -> [Double]? {
        guard let base = computeBaseEnergy(from: h) else { return nil }
        return Array(repeating: base, count: 24)          // flat until event-impact learner is added
    }

    // MARK: Base-energy score (0.0–1.0) -----------------------------------------
    private func computeBaseEnergy(from h: HealthEvent?) -> Double? {
        guard let h, h.hasSamples else { return nil }

        // --- Normalised inputs (0–1) ------------------------------------------
        let sleepEff   = norm(h.sleepEfficiency, 60, 100)         // %
        let hrvScore   = norm(h.hrv,              20, 120)        // ms
        let restHRInv  = 1.0 - norm(h.restingHR,  40, 100)        // bpm (lower is better)
        let deepREM    = norm(h.deepSleep + h.remSleep, 60, 300)  // minutes
        let actBal     = activityScore(steps: h.steps)            // z-score proximity

        // --- Weighted composite (literature-based) ----------------------------
        var e = 0.35*sleepEff +
                0.25*hrvScore +
                0.15*restHRInv +
                0.15*deepREM  +
                0.10*actBal

        // --- Circadian modifier (fixed lookup) -------------------------------
        let hr = calendar.component(.hour, from: Date())
        e += circadianBoost[hr]

        return max(0.0, min(1.0, e))
    }

    // MARK: Helpers -------------------------------------------------------------
    /// Simple min–max normalisation
    private func norm(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        guard hi > lo else { return 0.5 }
        return max(0.0, min(1.0, (v - lo) / (hi - lo)))
    }

    /// Activity score peaks when steps within ±1 SD of personal mean (placeholder)
    private func activityScore(steps: Int, mean: Int = 8000, sd: Int = 3000) -> Double {
        let z = Double(steps - mean) / Double(sd)
        return exp(-0.5 * z * z)                               // Gaussian bell, 0–1
    }

    /// Consensus circadian energy curve (dips ≈ 2 am & 3 pm; peaks ≈ 10 am & 6 pm)
    private let circadianBoost: [Double] = [
        -0.05,-0.05,-0.05,-0.04,-0.02,  // 0-4
         0.02, 0.06, 0.10, 0.12, 0.10,  // 5-9
         0.08, 0.05, 0.03, 0.00,-0.02,  // 10-14
        -0.04,-0.03, 0.00, 0.08, 0.12,  // 15-19
         0.10, 0.05, 0.00,-0.04         // 20-23
    ]
}
