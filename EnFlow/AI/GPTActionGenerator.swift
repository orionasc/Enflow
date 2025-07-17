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
    calendar: [CalendarEvent],
    forceRefresh: Bool = false
) async throws -> [ActionCard] {
    let prompt = buildPrompt(for: mode, hour: hour, energy: energy, hrv: hrv, sleep: sleep, calendar: calendar)

    let responseText = try await OpenAIManager.shared.generateInsight(
        prompt: "You are an expert rhythm and recovery assistant.\n" + prompt,
        maxTokens: 180,
        temperature: 0.7,
        forceRefresh: forceRefresh
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

🎯 CONTEXT:
You are an energy rhythm assistant inside a health-aware productivity app. The user just tapped an action mode. You must return short, clear, *actionable* ideas that are fresh and mentally stimulating — no fluff, no passivity.

⛔ DO NOT:
- Suggest yoga, meditation, deep breathing, warm baths, or tea
- Give any action that takes longer than 5 minutes
- Suggest anything that requires equipment or leaving the house
- Return generic platitudes like “take a break” or “breathe mindfully”
- Rescheduling anything critical, external, or time-sensitive. Only suggest changing tasks or blocks the user fully controls — internal work, flexible to-dos, or placeholder time.

✅ INSTEAD:
- Suggest actions that *shift mindset* or *unlock flow*
- Prioritize short, expressive ideas
- Consider user context: time of day, mental state, cognitive fatigue

---
📦 FORMAT (REQUIRED):
Return **only** valid, compact JSON — no markdown, no explanation:

[
  {
    \"title\": \"Short action title\",
    \"rationale\": \"Why this helps right now\",
    \"category\": \"boost\" | \"balance\" | \"replan\",
    \"urgency\": \"low\" | \"moderate\" | \"high\",
    \"tags\": [\"tag1\", \"tag2\"]
  },
  ...
]

✳️ MODE-SPECIFIC INSTRUCTIONS:

BOOST ME:
- Suggest quick, activating cognitive shifts (e.g. “change workspace”, “blast music for 1 min”, “step outside for 90 sec”)
- Assume the user is tired but must keep working
- Focus on energy redirection, stimulation, quick friction-breaking actions

BALANCE ME:
- Assume user is tense, overloaded, or mentally spun-up — help them *offload stress through action*
- Prefer brain-clearing moves (e.g. “jot down tomorrow’s tasks”, “move 1 meeting”, “send a 2-line status email”)
- Emphasize *resolution over relaxation*

RESCHEDULE ME:
- Help the user rebalance the rest of their day
- Suggest changes that make the next few hours smoother (e.g. “Cancel 1 low-value task”, “Schedule recovery time tomorrow AM”, “Auto-block 20 min between meetings”)
- Keep each suggestion fast and achievable

Only suggest things that take 1–5 minutes and give the user *relief, clarity, or momentum*.
*/

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
BOOST ME: Based on the context above, suggest 2–3 short, actionable ways to increase energy and focus *at this time of day*.

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
BALANCE ME: Based on the context above, suggest 2–3 calming or restorative actions to decompress or reset energy, relevant to current time.

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
RESCHEDULE ME: Based on the context above, suggest 2–3 short time or scheduling adjustments that would improve recovery, focus, or stress balance today or tomorrow.

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

Do NOT include explanations, code blocks, markdown, or preamble text. DO NOt suggest rescheduling anything critical, external, or time-sensitive. Only suggest changing tasks or blocks the user fully controls — internal work, flexible to-dos, or placeholder time.
The response must begin with `[` and end with `]`. Quotes must be straight.
"""
    }

    return context + "\n" + instructions
}

