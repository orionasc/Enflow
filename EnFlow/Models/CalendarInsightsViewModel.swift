//
//  CalendarInsightsViewModel.swift
//  EnFlow
//
//  Created by Codex.
//

import Foundation

@MainActor
class CalendarInsightsViewModel: ObservableObject {
    @Published var insights: [String] = []

    /// Generates insight text for each detected pattern using GPT and
    /// appends unique, confidence-sorted lines to ``insights``.
    func loadInsights(from patterns: [DetectedPattern]) async {
        guard !patterns.isEmpty else { return }

        let results = await withTaskGroup(of: (String, Double).self) { group in
            for pattern in patterns {
                group.addTask {
                    let text = await generateGPTInsight(from: pattern)
                    return (text, pattern.confidence)
                }
            }

            var collected: [(String, Double)] = []
            for await res in group { collected.append(res) }
            return collected
        }

        // Deduplicate keeping the highest confidence per text
        var unique: [String: Double] = [:]
        for (text, conf) in results {
            if let existing = unique[text] {
                if conf > existing { unique[text] = conf }
            } else {
                unique[text] = conf
            }
        }

        let sorted = unique.sorted { $0.value > $1.value }.map { $0.key }
        insights.append(contentsOf: sorted)
    }
}

