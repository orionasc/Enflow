//  SuggestedPrioritiesEngine.swift
//  EnFlow
//
//  Rev. 2025-06-17 PATCH-02
//  • Consolidates model layer (PriorityTemplate / TemplatePrompt / PriorityResult)
//  • Removes outdated SuggestedPriorityTemplate enum
//  • All API surface is internal (app-scope), no ‘public’ keywords
//  • Engine provides prompt-selection + feedback hooks only
//  ────────────────────────────────────────────────────────────────

import Foundation

// MARK: – Model single-source-of-truth  ───────────────────────────

enum PriorityTemplate: String, Codable, CaseIterable, Hashable, Identifiable {
    case focus, movement, rest, planning, mindfulness
    var id: String { rawValue }

    /// Matching SF Symbol
    var sfSymbol: String {
        switch self {
        case .focus:       "brain.head.profile"
        case .movement:    "figure.run"
        case .rest:        "bed.double.fill"
        case .planning:    "calendar"
        case .mindfulness: "sparkle"
        }
    }

    /// User-facing title
    var title: String { rawValue.capitalized }

    /// Short explainer used in info views
    var blurb: String {
        switch self {
        case .focus:       return "Deep work or tasks requiring high concentration."
        case .movement:    return "Quick physical activity to boost energy."
        case .rest:        return "Short rest strategies to recharge."
        case .planning:    return "Light planning or admin work."
        case .mindfulness: return "Mindfulness cues to reset your mind."
        }
    }
}

struct TemplatePrompt: Identifiable, Hashable, Codable {
    let id       = UUID()
    let template : PriorityTemplate
    let prompt   : String
}

struct PriorityResult: Identifiable, Hashable, Codable {
    let id        = UUID()
    let template  : PriorityTemplate
    let text      : String              // “Title\nBody”
    var rationale : String   = ""

    // Action-state (UI local)
    var isPinned        = false
    var snoozedUntil: Date?
    var isDismissed     = false

    var isSnoozed: Bool {
        if let until = snoozedUntil { return until > Date() }
        return false
    }

    /// Convenience used by OpenAIManager
    init(template: PriorityTemplate, text: String) {
        self.template = template
        self.text     = text
    }
}

// MARK: – SuggestedPrioritiesEngine  ──────────────────────────────

/// Handles template diversity + feedback weighting.
/// Thread-safe singleton (‘shared’) so all views converge on one cache.
@MainActor
final class SuggestedPrioritiesEngine: ObservableObject {

    // ── Singleton ────────────────────────────────────────────────
    static let shared = SuggestedPrioritiesEngine()
    private init() { loadCache() }           // private to enforce singleton

    // ── Diversity cache (template → weight) ──────────────────────
    private var templateWeights: [PriorityTemplate: Double] = [:] {
        didSet { saveCache() }
    }

    // ── Static prompt library (can live in JSON later) ───────────
    private(set) var prompts: [TemplatePrompt] = [
        .init(template: .focus,       prompt: "Suggest a single focus ritual..."),
        .init(template: .movement,    prompt: "Suggest a 5-min movement break..."),
        .init(template: .rest,        prompt: "Suggest a quick rest strategy..."),
        .init(template: .planning,    prompt: "Suggest a planning micro-task..."),
        .init(template: .mindfulness, prompt: "Suggest a 60-sec mindfulness cue...")
    ]

    // MARK: – Public API  ––––––––––––––––––––––––––––––––––––––––

    /// Returns *n* prompts, down-weighted for recently repeated templates.
    func nextPrompts(count n: Int) -> [TemplatePrompt] {
        let ranked = prompts.sorted { weight(for: $0.template) < weight(for: $1.template) }
        return Array(ranked.prefix(n))
    }

    /// Register user feedback (Pin / Dismiss) to tweak diversity.
    enum FeedbackAction { case pinned, dismissed }
    func registerFeedback(_ result: PriorityResult, action: FeedbackAction) {
        switch action {
        case .pinned:    bumpWeight(for: result.template, by: -0.3)   // more likely
        case .dismissed: bumpWeight(for: result.template, by:  0.5)   // less likely
        }
    }

    // MARK: – Weight helpers  ––––––––––––––––––––––––––––––––––––

    private func weight(for template: PriorityTemplate) -> Double {
        templateWeights[template] ?? 0
    }

    private func bumpWeight(for template: PriorityTemplate, by delta: Double) {
        let new = max(-1, min(3, weight(for: template) + delta))
        templateWeights[template] = new
    }

    // MARK: – Persistence  –––––––––––––––––––––––––––––––––––––––

    private let cacheKey = "priorityTemplateWeights.v1"
    private func saveCache() {
        if let data = try? JSONEncoder().encode(templateWeights) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let decoded = try? JSONDecoder().decode([PriorityTemplate: Double].self, from: data) {
            templateWeights = decoded
        }
    }
}
