//
//  OpenAIManager.swift
//  EnFlow
//
//  Rev. 2025-06-17
//  • Hour-bucket caching (≤ 1 call / h per prompt)
//  • Keychain key handling
//  • NEW: storeAPIKey(_:) so settings sheet can save / replace the key.
//

import Foundation
import SwiftUI

// ──────────────────────────────────────────────────────────────
// MARK: – In-memory + persisted cache (1 h TTL)
// ──────────────────────────────────────────────────────────────
private struct CachedEntry: Codable {
    let date: Date
    let text: String
}

private let cacheTTL: TimeInterval = 60 * 60          // 1 h
private let cacheStoreKey          = "OpenAIManager.Cache"

private var gptCache: [String: CachedEntry] = {
    guard let data = UserDefaults.standard.data(forKey: cacheStoreKey),
          let d    = try? JSONDecoder().decode([String: CachedEntry].self, from: data)
    else { return [:] }
    return d
}() {
    didSet {
        if let data = try? JSONEncoder().encode(gptCache) {
            UserDefaults.standard.set(data, forKey: cacheStoreKey)
        }
    }
}

// fallback key if caller omits an explicit cacheId
private func promptHash(system: String?, user: String) -> String {
    "\(system ?? "nil")|\(user)"
}

// ──────────────────────────────────────────────────────────────
// MARK: – Manager
// ──────────────────────────────────────────────────────────────
final class OpenAIManager {
    static let shared = OpenAIManager()
    private init() {}

    // Config
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!
    private let model    = "gpt-4o-mini"
    private lazy var apiKey: String = (try? KeychainHelper.read()) ?? ""

    // cached user profile context
    private var cachedProfile: (Date, String)? = nil

    // ───── PUBLIC API ──────────────────────────────────────────

    /// First-run or *Settings* sheet calls this once.
    @discardableResult
    func storeAPIKey(_ newKey: String) throws -> Bool {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        try KeychainHelper.save(trimmed)
        apiKey = trimmed                       // refresh in-memory copy
        return true
    }

    func generateInsight(prompt: String,
                         cacheId: String? = nil,
                         maxTokens: Int = 180,
                         temperature: Double = 0.6) async throws -> String {
        try await chatCompletion(
            system: systemPrompt,
            user:   prompt,
            cacheId: cacheId,
            maxTokens: maxTokens,
            temperature: temperature
        )
    }

    /// Runs all prompts in parallel; preserves order.
    // MARK: GPT: Suggested Priorities
    func generateSuggestedPriorities(_ prompts: [TemplatePrompt]) async throws -> [PriorityResult] {
        let hourBucket = Int(Date().timeIntervalSince1970 / 3_600)      // once per hour
        let formatRule = "Output exactly two lines: 1) a short title (≤6 words) 2) a body sentence. Insert ONE newline between them."

        return try await withThrowingTaskGroup(of: PriorityResult.self) { group in
            for p in prompts {
                group.addTask {
                    let cacheId = "SPE.\(p.template.rawValue).\(hourBucket)"
                    
                    // ── Raw GPT reply 
                    let raw = try await self.chatCompletion(
                        system: formatRule,
                        user:   p.prompt,
                        cacheId: cacheId,
                        maxTokens: 60,
                        temperature: 0.7
                    )
                  
                    let txt: String = {
                        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                
                        if trimmed.contains("\n") { return trimmed }
                        
                        // split after first sentence delimiter
                        if let idx = trimmed.firstIndex(where: { ".:?!".contains($0) }) {
                                                let title = String(trimmed[..<idx]).trimmingCharacters(in: .whitespaces)
                                                let bodyStart = trimmed.index(after: idx)
                                                let body  = String(trimmed[bodyStart...]).trimmingCharacters(in: .whitespaces)
                                                return "\(title)\n\(body)"
                        }
                        
                        return "Tip\n\(trimmed)"
                    }()
                    
                    return PriorityResult(template: p.template, text: txt)
                }
            }
            
            // Preserve original template order
            var ordered: [PriorityResult] = []
            for try await res in group { ordered.append(res) }
            return prompts.compactMap { tpl in ordered.first { $0.template == tpl.template } }
        }
    }

    // MARK: User context for prompts
    private func userDataContext() async -> String {
        if let cached = cachedProfile, Date().timeIntervalSince(cached.0) < 3_600 {
            return cached.1
        }

        let profile = UserProfileStore.load()
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"

        var parts: [String] = []
        parts.append("wake \(fmt.string(from: profile.typicalWakeTime))")
        parts.append("sleep \(fmt.string(from: profile.typicalSleepTime))")
        parts.append("chronotype \(profile.chronotype.rawValue)")
        parts.append("exercise \(profile.exerciseFrequency)/week")
        parts.append("caffeine \(profile.caffeineMgPerDay)mg")
        let times = [
            profile.caffeineMorning ? "morning" : nil,
            profile.caffeineAfternoon ? "afternoon" : nil,
            profile.caffeineEvening ? "evening" : nil
        ].compactMap { $0 }.joined(separator: ",")
        if !times.isEmpty { parts.append("caffeine times: \(times)") }
        if profile.usesSleepAid { parts.append("sleep aid") }
        if !profile.screensBeforeBed { parts.append("no screens before bed") }
        if !profile.mealsRegular { parts.append("irregular meals") }
        if let notes = profile.notes, !notes.isEmpty { parts.append("notes: \(notes)") }

        let health = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 14)
        let healthParts = health.map { "\(fmt.string(from: $0.date)): steps \($0.steps)" }

        let startPast = cal.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        let pastEvents = await CalendarDataPipeline.shared.fetchEvents(start: startPast, end: Date())
        let pastStr = pastEvents.map { "\(fmt.string(from: $0.startTime)): \($0.eventTitle)" }

        let upcoming = await CalendarDataPipeline.shared.fetchUpcomingDays(days: 7)
        let upcomingStr = upcoming.map { "\(fmt.string(from: $0.startTime)): \($0.eventTitle)" }

        let result = "Profile: \(parts.joined(separator: "; ")). Recent health: \(healthParts.joined(separator: ", ")). Recent events: \(pastStr.joined(separator: ", ")). Upcoming events: \(upcomingStr.joined(separator: ", "))."
        cachedProfile = (Date(), result)
        return result
    }


    

    // ───── Core call with cache-ID support ────────────────────
    private func chatCompletion(system: String?,
                                user: String,
                                cacheId: String?,
                                maxTokens: Int,
                                temperature: Double) async throws -> String {

        let context = await userDataContext()
        let userPrompt = context + "\n\n" + user

        let key = cacheId ?? promptHash(system: system, user: userPrompt)

        // return cached if still fresh
        if let hit = gptCache[key],
           Date().timeIntervalSince(hit.date) < cacheTTL {
            return hit.text
        }

        // build request
        var messages: [[String: String]] = []
        if let sys = system { messages.append(["role": "system", "content": sys]) }
        messages.append(["role": "user", "content": userPrompt])

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature
        ]

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)",          forHTTPHeaderField: "Authorization")
        req.setValue("application/json",          forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIError.api("Invalid server response")
        }

        guard (200..<300).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data).error.message {
                throw OpenAIError.api(err)
            } else {
                throw OpenAIError.api("Server returned status \(http.statusCode)")
            }
        }

        let decoded   = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        let text      = decoded.choices.first?.message.content
                            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        gptCache[key] = CachedEntry(date: Date(), text: text)   // persist
        return text
    }

    // Shared system prompt for general insights
    private let systemPrompt = """
    You are a wellness-focused AI coach helping users interpret biometric data \
    and schedules. Provide concise, actionable insights in plain text.
    """
}

// ───────────────────── Response decoding ───────────────────────
private struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        let message: Message
        struct Message: Decodable { let content: String }
    }
    let choices: [Choice]
}

private struct OpenAIErrorResponse: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}

enum OpenAIError: LocalizedError {
    case api(String)
    var errorDescription: String? {
        switch self {
        case .api(let msg): msg
        }
    }
}
