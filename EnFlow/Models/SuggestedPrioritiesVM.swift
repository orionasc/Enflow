//
//  SuggestedPrioritiesVM.swift
//  EnFlow
//
//  Created by Orion Goodman on 6/17/25.
//


// SuggestedPrioritiesVM.swift
// EnFlow
// Rev. 2025-06-17  • Handles local state, persistence, sorting & feedback

import Foundation
import SwiftUI

@MainActor
final class SuggestedPrioritiesVM: ObservableObject {
    @Published private(set) var priorities: [PriorityResult] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorText: String?

    private let storageKey = "enflow.suggestedPriorities.v1"

    init() {
        load()
    }

    /// Fetch new suggestions, merging any existing action‐state flags.
    func refresh(count: Int = 3) async {
        isLoading = true
        errorText = nil
        do {
            let prompts = SuggestedPrioritiesEngine.shared.nextPrompts(count: count)
            let results = try await OpenAIManager.shared.generateSuggestedPriorities(prompts)

            // Merge in old flags
            let oldMap = Dictionary(uniqueKeysWithValues: priorities.map { ($0.id, $0) })
            let merged = results.map { r -> PriorityResult in
                var copy = r
                if let old = oldMap[r.id] {
                    copy.isPinned     = old.isPinned
                    copy.snoozedUntil = old.snoozedUntil
                    copy.isDismissed  = old.isDismissed
                }
                return copy
            }

            priorities = sortAndFilter(merged)
            save()
        } catch {
            errorText = "Couldn’t fetch priorities."
        }
        isLoading = false
    }

    // MARK: – Actions

    func pin(_ p: PriorityResult) {
        impact(style: .light)
        update(p) { $0.isPinned.toggle() }
        SuggestedPrioritiesEngine.shared.registerFeedback(p, action: .pinned)
    }

    func snooze(_ p: PriorityResult) {
        impact(style: .light)
        update(p) { $0.snoozedUntil = Date().addingTimeInterval(2*3600) }
        SuggestedPrioritiesEngine.shared.registerFeedback(p, action: .dismissed)
    }

    func dismiss(_ p: PriorityResult) {
        impact(style: .soft)
        update(p) { $0.isDismissed = true }
        SuggestedPrioritiesEngine.shared.registerFeedback(p, action: .dismissed)
    }

    // MARK: – Private helpers

    private func update(_ p: PriorityResult, change: (inout PriorityResult)->()) {
        guard let idx = priorities.firstIndex(where: { $0.id == p.id }) else { return }
        change(&priorities[idx])
        priorities = sortAndFilter(priorities)
        save()
    }

    private func sortAndFilter(_ list: [PriorityResult]) -> [PriorityResult] {
        list
            .filter { !$0.isDismissed }
            .sorted {
                // pinned first
                if $0.isPinned != $1.isPinned { return $0.isPinned }
                // then non‐snoozed before snoozed
                if $0.isSnoozed != $1.isSnoozed { return !$0.isSnoozed }
                return false
            }
    }

    private func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    // MARK: – Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(priorities) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([PriorityResult].self, from: data) {
            priorities = sortAndFilter(decoded)
        }
    }
}
