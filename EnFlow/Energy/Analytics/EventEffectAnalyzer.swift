//  EventEffectAnalyzer.swift
//  EnFlow – Event-Type Energy Impact Summariser
//
//  Rev. 2025-06-17   PIVOT → Energy-only model
//  • Stress / recovery fields deleted.
//  • Aggregates per-category average `energyDelta` (-1…+1).
//  • Positive values are “boosters”, negative values are “drainers”.

import Foundation

// MARK: - Output model ----------------------------------------------------------
struct EventImpact: Identifiable {
    let id = UUID()
    let category: String
    let averageDelta: Double          // −1 … +1
    var netEffect: Double { averageDelta }   // kept for Chart y-axis
}

// MARK: - Analyzer --------------------------------------------------------------
final class EventEffectAnalyzer {
    
    /// Returns one `EventImpact` per high-level category
    /// - Parameter events: Any calendar events that already carry `energyDelta`
    func analyse(_ events: [CalendarEvent]) -> [EventImpact] {
        let grouped = Dictionary(grouping: events, by: categorize)
        
        return grouped.map { cat, evs in
            let deltas = evs.compactMap(\.energyDelta)
            let avg = deltas.average()
            return EventImpact(category: cat,
                               averageDelta: avg)
        }
        .sorted(by: { $0.averageDelta > $1.averageDelta })   // boosters first
    }
    
    // ─── Private helpers ──────────────────────────────────────────────────────
    
    /// Very simple keyword-based classifier (can refine later)
    private func categorize(_ event: CalendarEvent) -> String {
        let lower = event.eventTitle.lowercased()
        if lower.contains("meeting") { return "Meetings" }
        if lower.contains("call")    { return "Calls" }
        if lower.contains("gym") ||
           lower.contains("run")     { return "Workout" }
        if lower.contains("focus")   { return "Focus Work" }
        if lower.contains("lunch")   { return "Meals" }
        if lower.contains("sleep")   { return "Rest" }
        if lower.contains("yoga")    { return "Yoga" }
        return "Other"
    }
}

// MARK: - Collection helper -----------------------------------------------------
private extension Array where Element == Double {
    func average() -> Double {
        guard let s = self.nonEmptySum else { return 0 }
        return s / Double(self.count)
    }
    
    private var nonEmptySum: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +)
    }
}
