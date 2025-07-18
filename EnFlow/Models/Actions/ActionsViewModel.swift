import Foundation
import SwiftUI

@MainActor
final class ActionsViewModel: ObservableObject {
    @Published var cards: [ActionCard] = []
    @Published var isLoading: Bool = false
    @Published var mode: ActionMode = .boost

    func load(force: Bool = false) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let health = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 1)
            let todayHealth = health.first
            let events = await CalendarDataPipeline.shared.fetchEvents(for: Date())
            let profile = UserProfileStore.load()
            let summary = SummaryProvider.summary(
                for: Date(),
                healthEvents: health,
                calendarEvents: events,
                profile: profile
            )

            let energy = summary.overallEnergyScore / 100
            let hrv = min(max((todayHealth?.hrv ?? 60) / 120, 0), 1)
            let sleep = min(max((todayHealth?.sleepEfficiency ?? 70) / 100, 0), 1)

            self.cards = try await generateActions(
                mode: mode,
                hour: Calendar.current.component(.hour, from: Date()),
                energy: energy,
                hrv: hrv,
                sleep: sleep,
                calendar: events,
                forceRefresh: force
            )
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
private func fetchActionCards(for mode: ActionMode) async throws -> [ActionCard] {
    let hour = Calendar.current.component(.hour, from: Date())

    switch mode {
    case .boost:
        return boostCards(for: hour)
    case .balance:
        return balanceCards(for: hour)
    case .replan:
        return replanCards(for: hour)
    }
}

private func boostCards(for hour: Int) -> [ActionCard] {
    guard (6..<20).contains(hour) else { return [] }

    if hour < 12 {
        return [
            ActionCard(title: "Open the blinds",
                       rationale: "Morning light wakes your system",
                       category: .boost,
                       urgency: .moderate,
                       tags: ["Light"]),
            ActionCard(title: "Drink a glass of water",
                       rationale: "Rehydrates after sleep",
                       category: .boost,
                       urgency: .low,
                       tags: ["Hydration"]),
            ActionCard(title: "5‑min stretch",
                       rationale: "Loosen up for the day",
                       category: .boost,
                       urgency: .low,
                       tags: ["Move"])
        ]
    } else if hour < 17 {
        return [
            ActionCard(title: "Take a brisk 10‑min walk",
                       rationale: "Movement combats afternoon slump",
                       category: .boost,
                       urgency: .moderate,
                       tags: ["Afternoon dip"]),
            ActionCard(title: "Sip water or tea",
                       rationale: "Hydration helps focus",
                       category: .boost,
                       urgency: .low,
                       tags: ["Hydration"]),
            ActionCard(title: "Open a window",
                       rationale: "Fresh air perks you up",
                       category: .boost,
                       urgency: .low,
                       tags: ["Air"])
        ]
    } else {
        return [
            ActionCard(title: "Quick mobility stretch",
                       rationale: "Revive energy after sitting",
                       category: .boost,
                       urgency: .low,
                       tags: ["Move"]),
            ActionCard(title: "Drink a glass of water",
                       rationale: "Hydration lifts you",
                       category: .boost,
                       urgency: .low,
                       tags: ["Hydration"]),
            ActionCard(title: "Step outside briefly",
                       rationale: "Evening light resets circadian cues",
                       category: .boost,
                       urgency: .low,
                       tags: ["Light"])
        ]
    }
}

private func balanceCards(for hour: Int) -> [ActionCard] {
    if hour < 12 {
        return [
            ActionCard(title: "Plan a short break",
                       rationale: "Ease into the day calmly",
                       category: .balance,
                       urgency: .moderate,
                       tags: ["Morning"]),
            ActionCard(title: "3 deep breaths",
                       rationale: "Steadies mind before tasks",
                       category: .balance,
                       urgency: .low,
                       tags: ["Breathing"])
        ]
    } else if hour < 17 {
        return [
            ActionCard(title: "5‑min breathing reset",
                       rationale: "Calms stress between meetings",
                       category: .balance,
                       urgency: .moderate,
                       tags: ["Breathing"]),
            ActionCard(title: "Step away from screen",
                       rationale: "Let your eyes rest",
                       category: .balance,
                       urgency: .low,
                       tags: ["Break"]),
            ActionCard(title: "Protect next focus block",
                       rationale: "Set boundaries to reduce overload",
                       category: .balance,
                       urgency: .moderate,
                       tags: ["Boundaries"])
        ]
    } else {
        return [
            ActionCard(title: "Light stretch to unwind",
                       rationale: "Helps shift to evening mode",
                       category: .balance,
                       urgency: .low,
                       tags: ["Evening"]),
            ActionCard(title: "Jot down tomorrow's tasks",
                       rationale: "Clears mind before bed",
                       category: .balance,
                       urgency: .moderate,
                       tags: ["Plan"]),
            ActionCard(title: "Limit bright screens",
                       rationale: "Eases transition to sleep",
                       category: .balance,
                       urgency: .moderate,
                       tags: ["Night"])
        ]
    }
}

private func replanCards(for hour: Int) -> [ActionCard] {
    return [
        ActionCard(title: "Review tomorrow's calendar",
                   rationale: "Shift heavy items where energy is higher",
                   category: .replan,
                   urgency: .moderate,
                   tags: ["Schedule"]),
        ActionCard(title: "Block a 10‑min break",
                   rationale: "Create room to recover",
                   category: .replan,
                   urgency: .high,
                   tags: ["Recovery"]),
        ActionCard(title: "Prep for deep work",
                   rationale: "Gather materials now to start smoothly",
                   category: .replan,
                   urgency: .low,
                   tags: ["Focus"])
    ]
}

