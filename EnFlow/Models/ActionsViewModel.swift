import Foundation
import SwiftUI

@MainActor
final class ActionsViewModel: ObservableObject {
    @Published var cards: [ActionCard] = []
    @Published var isLoading: Bool = false

    func load(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            self.cards = try await fetchGPTActionCards()
        } catch {
            self.cards = []
        }
    }

    func markDone(_ card: ActionCard) {
        // Store or log action
    }

    func dismiss(_ card: ActionCard) {
        cards.removeAll { $0.id == card.id }
    }
}

// Temporary stub – replace with real GPT integration
private func fetchGPTActionCards() async throws -> [ActionCard] {
    return [
        ActionCard(
            title: "Take a 10-min walk",
            rationale: "Boosts alertness after sitting",
            category: .boost,
            urgency: .moderate,
            tags: ["Afternoon dip"]
        )
    ]
}

