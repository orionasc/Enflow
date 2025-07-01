//
//  CalendarEventClassifier.swift
//  EnFlow
//
//  Created by OpenAI Assistant on 2025-06-18.
//  Simple heuristic classifier for calendar events.
//

import Foundation

/// Classifies a `CalendarEvent` as a "Booster", "Drainer" or "Neutral" with a confidence score.
struct CalendarEventClassifier {
    struct Result {
        let label: String        // Booster, Drainer, Neutral
        let confidence: Double   // 0.0 … 1.0
    }

    private let calendar = Calendar.current

    func classify(_ event: CalendarEvent) -> Result {
        let title = event.eventTitle.lowercased()
        let duration = event.endTime.timeIntervalSince(event.startTime)
        let hour = calendar.component(.hour, from: event.startTime)

        // Booster heuristics -------------------------------------------------
        if title.contains("walk") || title.contains("run") || title.contains("gym") {
            let confidence = duration <= 3600 ? 0.8 : 0.6
            return Result(label: "Booster", confidence: confidence)
        }

        // Drainer heuristics -------------------------------------------------
        if title.contains("meeting") || title.contains("call") {
            if duration >= 3600 && (12...17).contains(hour) {
                return Result(label: "Drainer", confidence: 0.8)
            } else if duration >= 1800 {
                return Result(label: "Drainer", confidence: 0.6)
            }
        }
        if duration > 7200 {
            return Result(label: "Drainer", confidence: 0.5)
        }

        // Neutral fallback ---------------------------------------------------
        return Result(label: "Neutral", confidence: 0.5)
    }
}
