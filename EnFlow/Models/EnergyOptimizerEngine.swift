//  EnergyOptimizerEngine.swift
//  EnFlow – Schedule-Optimization Heuristics
//
//  ⬆︎ Patch 2025-06-17
//  • Skip all-day items and weekend/holiday events.
//

import Foundation

struct OptimizationSuggestion: Identifiable {
    let id = UUID()
    let change: String   // e.g. “Move ‘Gym’ to 9 AM”
    let reason: String   // e.g. “Energy at 9 AM is higher than current slot.”
}

final class EnergyOptimizerEngine {
    private let calendar = Calendar.current

    /// Returns move/shift suggestions for a single **day**.
    func suggest(for date: Date,
                 events: [CalendarEvent],
                 forecast: [Double]) -> [OptimizationSuggestion] {

        var out: [OptimizationSuggestion] = []

        for ev in events where calendar.isDate(ev.startTime, inSameDayAs: date) {

            // ─── NEW: ignore all-day + weekend/holiday ─────────────────────────────
            guard ev.isAllDay == false,
                  calendar.isDateInWeekend(ev.startTime) == false else { continue }

            let startHr = calendar.component(.hour, from: ev.startTime)
            let energy  = forecast[safe: startHr] ?? 0.5

            // Heuristic: move if energy < 0.40 at present slot
            if energy < 0.40,
               let betterHr = findBetterHour(forecast, around: startHr) {

                let newTime = formattedHour(betterHr)
                out.append(
                    OptimizationSuggestion(
                        change: "Move ‘\(ev.eventTitle)’ to \(newTime)",
                        reason: "Predicted energy at \(newTime) is higher than current slot."
                    )
                )
            }
        }
        return out
    }

    // MARK: – Helpers ------------------------------------------------------------

    private func findBetterHour(_ wave: [Double], around hr: Int) -> Int? {
        let window = (0..<24).filter { abs($0 - hr) <= 4 && $0 != hr }
        return window.max(by: { wave[safe:$0] ?? 0 < wave[safe:$1] ?? 0 })
    }

    private func formattedHour(_ hr: Int) -> String {
        var c = DateComponents(); c.hour = hr
        let d = calendar.date(from: c) ?? Date()
        let f = DateFormatter(); f.dateFormat = "h a"
        return f.string(from: d)
    }
}

// MARK: – Safe-index array access
private extension Array {
    subscript(safe idx: Int) -> Element? {
        indices.contains(idx) ? self[idx] : nil
    }
}
