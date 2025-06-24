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
    let hasSamples: Bool            // true if HealthKit returned data
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

        // Sub-scores
        let mental   = computeMentalEnergy(from: hRows)
        let physical = computePhysicalEnergy(from: hRows)
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

        return DayEnergySummary(
            date: start,
            overallEnergyScore: overall.rounded(),
            mentalEnergy: mental.rounded(),
            physicalEnergy: physical.rounded(),
            sleepEfficiency: avg(hRows.map(\.sleepEfficiency), min: 60, max: 100) * 100,
            hourlyWaveform: wave,
            topBoosters: boosters,
            topDrainers: drainers,
            explainers: drivers
        )
    }

    // ───────── Sub-score helpers ─────────────────────────────────
    private func computeMentalEnergy(from rows: [HealthEvent]) -> Double {
        guard !rows.isEmpty else { return 50 }
        let rem     = avg(rows.map(\.remSleep),      min: 0,  max: 180)
        let hrv     = avg(rows.map(\.hrv),           min: 20, max: 120)
        let latency = 1 - avg(rows.map(\.sleepLatency), min: 0, max: 60)
        return (rem + hrv + latency) / 3 * 100
    }

    private func computePhysicalEnergy(from rows: [HealthEvent]) -> Double {
        guard !rows.isEmpty else { return 50 }
        let deep     = avg(rows.map(\.deepSleep),      min: 0,  max: 120)
        let restHR   = 1 - avg(rows.map(\.restingHR),  min: 40, max: 100)
        let sleepEff = avg(rows.map(\.sleepEfficiency),min: 60, max: 100)
        return (deep + restHR + sleepEff) / 3 * 100
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
