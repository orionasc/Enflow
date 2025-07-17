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
    /// Debug string describing input coverage and confidence.
    let debugInfo: String

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
    let heartRate: Double           // bpm
    let sleepEfficiency: Double     // %
    let sleepLatency: Double        // min
    let deepSleep: Double           // min
    let remSleep: Double            // min
    let timeInBed: Double           // min
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
    /// Fixed circadian energy curve used to weight hourly scores.
    private let circadianBoost: [Double] = [
        -0.05, -0.05, -0.05, -0.04, -0.02,
        0.02, 0.06, 0.10, 0.12, 0.10,
        0.08, 0.05, 0.03, 0.00, -0.02,
        -0.04, -0.03, 0.00, 0.08, 0.12,
        0.10, 0.05, 0.00, -0.04,
    ]

    @MainActor @Published private(set) var refreshVersion = 0   // ring-pulse

    /// Caller should invoke after **any** new fetch so rings can animate a pulse.
    @MainActor     func markRefreshed() { refreshVersion &+= 1 }

    // ───────── Public API ─────────────────────────────────────────
    @discardableResult
    func summarize(day: Date,
                   healthEvents: [HealthEvent],
                   calendarEvents: [CalendarEvent],
                   profile: UserProfile? = nil) -> DayEnergySummary {

        let start = calendar.startOfDay(for: day)
        let end   = calendar.date(byAdding: .day, value: 1, to: start) ?? start

        // Day-slice the inputs
        let hRows = healthEvents.filter { $0.date       >= start && $0.date < end }
        let cRows = calendarEvents.filter { $0.startTime >= start && $0.startTime < end }

        // Eligibility check -------------------------------------------------
        if let h = hRows.first, !isEnergyEligible(h) {
            let missing = missingRequiredMetrics(h)
            let debug = "missing: \(missing.map { $0.rawValue }.joined(separator: ","))"
            return DayEnergySummary(
                date: start,
                overallEnergyScore: 0,
                mentalEnergy: 0,
                physicalEnergy: 0,
                sleepEfficiency: 0,
                coverageRatio: Double(h.availableMetrics.count) / Double(MetricType.allCases.count),
                confidence: 0,
                warning: "Insufficient health data",
                debugInfo: debug,
                hourlyWaveform: Array(repeating: 0, count: 24),
                topBoosters: [],
                topDrainers: [],
                explainers: []
            )
        }

        // Sub-scores with fallback logic
        let mental   = computeMentalEnergy(from: hRows.first)
        let physical = computePhysicalEnergy(from: hRows.first)
        let rawOverall = (mental + physical) / 2.0
        let overall = baselineAdjusted(rawOverall, profile: profile)

        // 24-h waveform (starts flat, apply event deltas)
        let wave = hourlyWaveform(base: overall / 100.0, events: cRows, start: start, profile: profile)

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
        let required: Set<MetricType> = [
            .stepCount,
            .activeEnergyBurned,
            .heartRate,
            .timeInBed
        ]
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

        let debug = "\(available.count)/\(MetricType.allCases.count) signals, conf \(String(format: "%.2f", confidence))"

        return DayEnergySummary(
            date: start,
            overallEnergyScore: overall.rounded(),
            mentalEnergy: mental.rounded(),
            physicalEnergy: physical.rounded(),
            sleepEfficiency: avg(hRows.map(\.sleepEfficiency), min: 60, max: 100) * 100,
            coverageRatio: coverage,
            confidence: confidence,
            warning: warning,
            debugInfo: debug,
            hourlyWaveform: wave,
            topBoosters: boosters,
            topDrainers: drainers,
            explainers: drivers
        )
    }

    // MARK: – Sub-score helpers
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

        // Fallback when rich sleep/HRV data isn’t available
        if comps.isEmpty {
            let estSteps = projectedSteps(h.steps, for: h.date, calendar: calendar)
            comps.append(max(activityScore(steps: estSteps), 0.35))    // floor at 35 %
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

        // Fallback when nothing else is usable
        if comps.isEmpty {
            let estSteps = projectedSteps(h.steps, for: h.date, calendar: calendar)
            comps.append(max(activityScore(steps: estSteps), 0.35))
        }
        return comps.reduce(0, +) / Double(comps.count) * 100
    }


    // ───────── Waveform builder ──────────────────────────────────
    private func hourlyWaveform(base: Double,
                                events: [CalendarEvent],
                                start: Date,
                                profile: UserProfile?) -> [Double] {
        var wave = circadianBoost.map { max(0, min(1, base + $0)) }
        for ev in events {
            guard let delta = ev.energyDelta else { continue }
            let hr = calendar.component(.hour, from: ev.startTime)
            if hr >= 0 && hr < 24 {
                wave[hr] = max(0, min(1, wave[hr] + delta))
            }
        }
        shapeBedWake(for: start, profile: profile, into: &wave)
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


    /// Adjusts raw 0–100 scores so that ~50 maps near 70 while
    /// preserving variability and applying profile bias.
    private func baselineAdjusted(_ raw: Double,
                                  profile: UserProfile?) -> Double {
        let v = max(0, min(100, raw))
        let shifted: Double
        if v <= 50 {
            shifted = v / 50.0 * 70.0
        } else {
            shifted = 70.0 + (v - 50.0) / 50.0 * 30.0
        }
        guard let p = profile else { return shifted }
        var bias = 0.0
        if p.caffeineMgPerDay > 300 { bias -= 5 }
        if p.usesSleepAid { bias -= 3 }
        if p.screensBeforeBed { bias -= 2 }
        if !p.mealsRegular { bias -= 2 }
        if p.exerciseFrequency >= 5 { bias += 3 }
        if p.exerciseFrequency <= 1 { bias -= 3 }
        switch p.chronotype {
        case .morning: bias += 2
        case .evening: bias -= 2
        default: break
        }
        return min(max(0, shifted + bias), 100)
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

private func shapeBedWake(for date: Date,
                          profile: UserProfile?,
                          calendar: Calendar = .current,
                          into wave: inout [Double]) {
    guard let p = profile else { return }
    let bedHr  = calendar.component(.hour, from: p.typicalSleepTime)
    let wakeHr = calendar.component(.hour, from: p.typicalWakeTime)

    // ---- Day-specific random-ish magnitude (8–15 %) ----
    let seed = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    let rand = Double((seed &* 1664525 &+ 1013904223) % 1000) / 1000.0
    let mag  = 0.08 + rand * 0.07          // 0.08 … 0.15

    // ---- Downtick: last 1-3 h before bed ----
    let downSpan = max(1, Int(1 + rand * 2))  // 1-3 h
    for i in 0..<downSpan {
        let h = (bedHr - 1 - i + 24) % 24
        let factor = mag * Double(i + 1) / Double(downSpan)
        wave[h] = max(0, wave[h] - factor)
    }

    // ---- Uptick: first 1-3 h after wake ----
    let upSpan = max(1, Int(1 + (1 - rand) * 2))  // 1-3 h (inverse of rand)
    for i in 0..<upSpan {
        let h = (wakeHr + i) % 24
        let factor = mag * 0.6 * Double(upSpan - i) / Double(upSpan)
        wave[h] = min(1, wave[h] + factor)
    }

    // ---- Hard floor for end-of-day value ----
    wave[23] = min(wave[23], 0.50)
}
