//
//  CalendarDataPipeline.swift
//  EnFlow
//
//  Rev. 2025-06-17  Pivot → Energy-only model
//  • CalendarEvent gains `energyDelta` (optional, −1…+1 range suggested)
//  • Legacy `predictedStress` / `predictedRecovery` kept as *deprecated* computed
//    vars that always return 0 so existing code still compiles while we phase
//    them out.
//

import Foundation
import EventKit

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Calendar Event Model
struct CalendarEvent: Identifiable {
    let id = UUID()

    // — Core —
    let eventTitle: String
    let startTime:  Date
    let endTime:    Date
    let isAllDay:   Bool

    // — New energy-specific field (filled later by EventEnergyImpactLearner) —
    var energyDelta: Double? = nil    // positive boosts, negative drains (-1…+1)

    // MARK: Legacy shim (always 0) — will be deleted after full refactor
    @available(*, deprecated, message: "Stress model removed; always 0.")
    var predictedStress: Double { 0 }

    @available(*, deprecated, message: "Recovery model removed; always 0.")
    var predictedRecovery: Double { 0 }
}

// MARK: - Calendar Data Pipeline
final class CalendarDataPipeline: ObservableObject {
    static let shared = CalendarDataPipeline()
    private let store = EKEventStore()
    private init() {}

    /// Requests Calendar permission.
    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestAccess(to: .event) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    /// Loads events within the range and maps to `CalendarEvent`.
    func fetchEvents(start: Date, end: Date) async -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let ekEvents  = store.events(matching: predicate)

        let calendarEvents = ekEvents.map { ek in
            CalendarEvent(
                eventTitle: ek.title ?? "(No Title)",
                startTime:  ek.startDate,
                endTime:    ek.endDate,
                isAllDay:   ek.isAllDay,
                energyDelta: nil               // will be learned later
            )
        }
        return calendarEvents.sorted(by: { $0.startTime < $1.startTime })
    }

    /// Convenience: upcoming N-day window.
    func fetchUpcomingDays(days: Int = 7) async -> [CalendarEvent] {
        let cal = Calendar.current
        let now = Date()
        let end = cal.date(byAdding: .day, value: days, to: now) ?? now
        return await fetchEvents(start: now, end: end)
    }

    /// Single-day fetch.
    func fetchEvents(for date: Date) async -> [CalendarEvent] {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: date)
        let endDay   = cal.date(byAdding: .day, value: 1, to: startDay) ?? startDay
        return await fetchEvents(start: startDay, end: endDay)
    }
}
