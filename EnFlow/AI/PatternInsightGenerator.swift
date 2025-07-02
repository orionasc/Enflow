//
//  PatternInsightGenerator.swift
//  EnFlow
//
//  Created by Codex.
//

import Foundation

/// Generates a short plain English insight summarizing the given `DetectedPattern` using GPT-4.
/// Falls back to a default message if GPT is unavailable.
func generateGPTInsight(from pattern: DetectedPattern) async -> String {
    let prompt = """
    Summarize this pattern for a user:
    Pattern: '\(pattern.pattern)'
    Effect: '\(pattern.effect)'
    Evidence: \(pattern.evidenceCount) days
    Confidence: \(pattern.confidence)
    """

    do {
        let text = try await OpenAIManager.shared.generateInsight(
            prompt: prompt,
            cacheId: pattern.id.uuidString
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    } catch {
        return "EnFlow is working on your predictions, stay tuned for updates!..."
    }
}
