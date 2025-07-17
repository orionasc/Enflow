//
//  GPTActionGenerator.swift
//  EnFlow
//
//  Created by Orion Goodman on 7/16/25.
//

import Foundation

struct GPTActionCardResponse: Codable {
    let title: String
    let rationale: String
    let category: ActionCategory
    let urgency: ActionUrgencyLevel
    let tags: [String]
}

func generateActions(
    mode: ActionMode,
    hour: Int,
    energy: Double,
    hrv: Double,
    sleep: Double,
    calendar: [CalendarEvent]
) async throws -> [ActionCard] {
    let prompt = buildPrompt(for: mode, hour: hour, energy: energy, hrv: hrv, sleep: sleep, calendar: calendar)

    let responseText = try await OpenAIManager.shared.generateInsight(
        prompt: "You are an expert rhythm and recovery assistant.\n" + prompt,
        maxTokens: 180,
        temperature: 0.7
    )

    guard responseText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("[") else {
        throw URLError(.cannotParseResponse)
    }

    guard let data = responseText.data(using: .utf8) else {
        throw URLError(.badServerResponse)
    }

    let rawCards = try JSONDecoder().decode([GPTActionCardResponse].self, from: data)

    return rawCards.map { raw in
        ActionCard(
            title: raw.title,
            rationale: raw.rationale,
            category: raw.category,
            urgency: raw.urgency,
            tags: raw.tags
        )
    }
}

private func buildPrompt(
    for mode: ActionMode,
    hour: Int,
    energy: Double,
    hrv: Double,
    sleep: Double,
    calendar: [CalendarEvent]
) -> String {
    let context = """
Current time: \(hour):00
Energy score: \(Int(energy * 100))
HRV score: \(Int(hrv * 100))
Sleep score: \(Int(sleep * 100))
Upcoming events: \(calendar.prefix(3).map { $0.eventTitle }.joined(separator: ", "))
"""

    let instructions: String
    switch mode {
    case .boost:
        instructions = """
Based on the context above, suggest 2–3 short, actionable ways to increase energy and focus *at this time of day*.

Return only a valid, compact JSON array, in plaintext, formatted exactly like this:

[
  {
    "title": "Short title here",
    "rationale": "Why this action matters",
    "category": "boost",
    "urgency": "moderate",
    "tags": ["tag1", "tag2"]
  },
  ...
]

Do NOT include explanations, code blocks, markdown, or preamble text.
The response must begin with `[` and end with `]`. Quotes must be straight.
"""
    case .balance:
        instructions = """
Based on the context above, suggest 2–3 calming or restorative actions to decompress or reset energy, relevant to current time.

Return only a valid, compact JSON array, in plaintext, formatted exactly like this:

[
  {
    "title": "Short title here",
    "rationale": "Why this action matters",
    "category": "balance",
    "urgency": "low",
    "tags": ["tag1", "tag2"]
  },
  ...
]

Do NOT include explanations, code blocks, markdown, or preamble text.
The response must begin with `[` and end with `]`. Quotes must be straight.
"""
    case .replan:
        instructions = """
Based on the context above, suggest 2–3 short time or scheduling adjustments that would improve recovery, focus, or stress balance today or tomorrow.

Return only a valid, compact JSON array, in plaintext, NO MARKDOWN, formatted exactly like this:

[
  {
    "title": "Short title here",
    "rationale": "Why this action matters",
    "category": "replan",
    "urgency": "high",
    "tags": ["tag1", "tag2"]
  },
  ...
]

Do NOT include explanations, code blocks, markdown, or preamble text.
The response must begin with `[` and end with `]`. Quotes must be straight.
"""
    }

    return context + "\n" + instructions
}
