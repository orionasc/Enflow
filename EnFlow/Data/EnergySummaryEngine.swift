//
//  EnergySummaryEngine.swift
//  EnFlow
//
//  Rev. 2025-06-17 PATCH-02
//  ──────────────────────────────────────────────────────────────
//  • ObservableObject + singleton (`shared`) so views can observe
//    `forecastVersion` for ring-pulse micro-interactions.
//  • @Published `forecastVersion` ticks whenever you call
//    `markRefreshed()` after a new Health/Calendar fetch.
//  • Adds `explainers` bullet array in DayEnergySummary for the
//    upcoming “Why this?” bottom-sheet.
//  • Energy-only model: relies on `CalendarEvent.energyDelta`
//    (−1…+1). No legacy stress/recovery code remains.
//  • Pure Swift + Foundation/HealthKit — should compile cleanly
//    with the rest of the current EnFlow sources.
//

import Foundation
import HealthKit

// MARK: – Day-level output ------------------------------------------------------

struct DayEnergySummary: Identifiable {
    let id = UUID()
    let date: Date

    let overallEnergyScore: Double      // 0…100
    let mentalEnergy: Double            // 0…100
    let physicalEnergy: Double          // 0…100
    let sleepEfficiency: Double         // 0…100

    /// Ratio of available metrics used to compute this score (0…1).
    let coverageRatio: Double
    /// Confidence level for the energy estimate (0…1).
    let confidence: Double
    /// Warning message if limited data required fallback logic.
    let warning: String?

    let hourlyWaveform: [Double]        // 24 values, 0.0…1.0
    let topBoosters: [String]           // event titles
    let topDrainers: [String]           // event titles
    var explainers: [String] = []       // ≤5 bullet “why” drivers
}

// MARK: – Daily aggregate from HealthKit --------------------------------------

struct HealthEvent {
    let date: Date
    let hrv: Double                 // ms
    let restingHR: Double           // bpm
    let sleepEfficiency: Double     // %
    let sleepLatency: Double        // min
    let deepSleep: Double           // min
    let remSleep: Double            // min
    let steps: Int
    let calories: Double            // kcal

    /// Which metrics were available for this day.
    let availableMetrics: Set<MetricType>

    /// true if HealthKit returned any data
    let hasSamples: Bool
}

// MARK: – Energy summary engine -----------------------------------------------

final class EnergySummaryEngine: ObservableObject {

    // — Singleton access (for UI observation) —
    static let shared = EnergySummaryEngine()
    private init() {}

    private let calendar = Calendar.current

    @MainActor @Published private(set) var refreshVersion = 0   // ring-pulse

    /// Caller should invoke after **any** new fetch so rings can animate a pulse.
    @MainActor     func markRefreshed() { refreshVersion &+= 1 }

    // ───────── Public API ─────────────────────────────────────────
    @discardableResult
    func summarize(day: Date,
                   healthEvents: [HealthEvent],
                   calendarEvents: [CalendarEvent]) -> DayEnergySummary {

        let start = calendar.startOfDay(for: day)
        let end   = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        // Day-slice the inputs
        let hRows = healthEvents.filter { $0.date       >= start && $0.date < end }
        let cRows = calendarEvents.filter { $0.startTime >= start && $0.startTime < end }

        // Sub-scores with fallback logic
        let mental   = computeMentalEnergy(from: hRows.first)
        let physical = computePhysicalEnergy(from: hRows.first)
        let overall  = (mental + physical) / 2.0

        // 24-h waveform (starts flat, apply event deltas)
        let wave = hourlyWaveform(base: overall / 100.0, events: cRows)

        // Top boosters / drainers
        let boosters = topEvents(from: cRows, positive: true)
        let drainers = topEvents(from: cRows, positive: false)

        // Explain-on-Demand bullet list
        let drivers = buildExplainers(health: hRows.first,
                                      overall: overall,
                                      mental: mental,
                                      physical: physical,
                                      events: cRows)

        let available = hRows.first?.availableMetrics ?? []
        let coverage = Double(available.count) / Double(MetricType.allCases.count)
        let required: Set<MetricType> = [.stepCount, .restingHR, .activeEnergyBurned]
        var warning: String? = nil
        var confidence: Double = 0.6
        if required.isSubset(of: available) == false {
            confidence = 0.2
            warning = "⚠️ Limited data used for today’s estimate. Add sleep or HRV data for higher accuracy."
        } else if available.count == required.count {
            confidence = 0.4
            warning = "⚠️ Limited data used for today’s estimate. Add sleep or HRV data for higher accuracy."
        } else if available.count >= 5 {
            confidence = 0.8
        }

        return DayEnergySummary(
            date: start,
            overallEnergyScore: overall.rounded(),
            mentalEnergy: mental.rounded(),
            physicalEnergy: physical.rounded(),
            sleepEfficiency: avg(hRows.map(\.sleepEfficiency), min: 60, max: 100) * 100,
            coverageRatio: coverage,
            confidence: confidence,
            warning: warning,
            hourlyWaveform: wave,
            topBoosters: boosters,
            topDrainers: drainers,
            explainers: drivers
        )
    }

    // ───────── Sub-score helpers ─────────────────────────────────
    private func computeMentalEnergy(from event: HealthEvent?) -> Double {
        guard let h = event else { return 50 }
        var comps: [Double] = []
        if h.availableMetrics.contains(.remSleep) {
            comps.append(norm(h.remSleep, 0, 180))
        }
        if h.availableMetrics.contains(.sleepLatency) {
            comps.append(1 - norm(h.sleepLatency, 0, 60))
        }
        if h.availableMetrics.contains(.heartRateVariabilitySDNN) {
            comps.append(norm(h.hrv, 20, 120))
        } else if h.availableMetrics.contains(.restingHR) {
            comps.append(1 - norm(h.restingHR, 40, 100))
        }
        if comps.isEmpty {
            comps.append(activityScore(steps: h.steps))
        }
        return comps.reduce(0, +) / Double(comps.count) * 100
    }

    private func computePhysicalEnergy(from event: HealthEvent?) -> Double {
        guard let h = event else { return 50 }
        var comps: [Double] = []
        if h.availableMetrics.contains(.deepSleep) {
            comps.append(norm(h.deepSleep, 0, 120))
        }
        if h.availableMetrics.contains(.restingHR) {
            comps.append(1 - norm(h.restingHR, 40, 100))
        } else if h.availableMetrics.contains(.heartRateVariabilitySDNN) {
            comps.append(norm(h.hrv, 20, 120))
        }
        if h.availableMetrics.contains(.sleepEfficiency) {
            comps.append(norm(h.sleepEfficiency, 60, 100))
        }
        if comps.isEmpty {
            let activity = activityScore(steps: h.steps)
            comps.append(activity)
        }
        return comps.reduce(0, +) / Double(comps.count) * 100
    }

    // ───────── Waveform builder ──────────────────────────────────
    private func hourlyWaveform(base: Double,
                                events: [CalendarEvent]) -> [Double] {
        var wave = Array(repeating: base, count: 24)
        for ev in events {
            guard let delta = ev.energyDelta else { continue }
            let hr = calendar.component(.hour, from: ev.startTime)
            wave[hr] = max(0, min(1, wave[hr] + delta))
        }
        return wave
    }

    // ───────── Utility helpers ───────────────────────────────────
    /// Min-max normalise → 0…1
    private func avg(_ vals: [Double], min lo: Double, max hi: Double) -> Double {
        let valid = vals.filter { $0 > 0 }
        guard !valid.isEmpty else { return 0.5 }
        let mean = valid.reduce(0, +) / Double(valid.count)
        return max(0, min(1, (mean - lo) / (hi - lo)))
    }

    /// Simple min–max normalisation
    private func norm(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
        guard hi > lo else { return 0.5 }
        return max(0.0, min(1.0, (v - lo) / (hi - lo)))
    }

    /// Activity score peaks near personal mean step count (placeholder logic)
    private func activityScore(steps: Int, mean: Int = 8000, sd: Int = 3000) -> Double {
        let z = Double(steps - mean) / Double(sd)
        return exp(-0.5 * z * z)
    }

    private func topEvents(from events: [CalendarEvent],
                           positive: Bool,
                           limit: Int = 3) -> [String] {
        events
            .filter { $0.energyDelta != nil }
            .sorted {
                guard let a = $0.energyDelta, let b = $1.energyDelta else { return false }
                return positive ? a > b : a < b
            }
            .prefix(limit)
            .map(\.eventTitle)
    }

    private func buildExplainers(health: HealthEvent?,
                                 overall: Double,
                                 mental: Double,
                                 physical: Double,
                                 events: [CalendarEvent]) -> [String] {

        var out: [String] = []

        if let h = health {
            out.append("Sleep efficiency \(Int(h.sleepEfficiency)) %")
            out.append("HRV \(Int(h.hrv)) ms")
            out.append("Resting HR \(Int(h.restingHR)) bpm")
        }

        // Quick morning-meeting detector
        let amMeetings = events.filter {
            $0.eventTitle.lowercased().contains("meeting") &&
            calendar.component(.hour, from: $0.startTime) < 12
        }
        if !amMeetings.isEmpty { out.append("\(amMeetings.count) morning meeting(s)") }

        out.append("Mental \(Int(mental)) / Physical \(Int(physical))")

        return Array(out.prefix(5))
    }
}
