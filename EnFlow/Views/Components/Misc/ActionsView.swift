//
//  ActionsView.swift
//  EnFlow
//
//  Created by Codex.
//

import SwiftUI

// MARK: - Data Models -----------------------------------------------------------
enum ActionCategory: String, Codable, CaseIterable {
    case boost, balance, replan
}

enum ActionUrgencyLevel: String, Codable {
    case low, moderate, high
}

enum ActionMode: String, CaseIterable, Identifiable {
    case boost, balance, replan
    var id: String { rawValue }

    var label: String {
        switch self {
        case .boost:   return "Boost Me"
        case .balance: return "Balance Me"
        case .replan:  return "Reschedule Me"
        }
    }
}

struct ActionCard: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let rationale: String
    let category: ActionCategory
    let urgency: ActionUrgencyLevel
    let tags: [String]

    init(id: UUID = UUID(), title: String, rationale: String, category: ActionCategory, urgency: ActionUrgencyLevel, tags: [String]) {
        self.id = id
        self.title = title
        self.rationale = rationale
        self.category = category
        self.urgency = urgency
        self.tags = tags
    }

    static func == (lhs: ActionCard, rhs: ActionCard) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Main View -------------------------------------------------------------
struct ActionsView: View {
    @StateObject private var vm = ActionsViewModel()
    @State private var selectedCard: ActionCard? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Picker("", selection: $vm.mode) {
                ForEach(ActionMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if vm.isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if vm.cards.isEmpty {
                Text("No actions available right now.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(vm.cards) { card in
                    ActionCardView(card: card)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Done") { vm.markDone(card) }
                                .tint(.green)
                            Button("Hide") { vm.dismiss(card) }
                                .tint(.gray)
                            Button("Why?") { selectedCard = card }
                                .tint(.blue)
                        }
                }
            }
        }
        .sheet(item: $selectedCard) { card in
            ExplainSheetView(header: card.title, bullets: [card.rationale], timestamp: Date(), template: nil)
        }
        .task { await vm.load() }
        .onChange(of: vm.mode) { _ in
            Task { await vm.load(force: true) }
        }
        .animation(.easeInOut, value: vm.cards)
    }

    private var header: some View {
        HStack {
            Text("Actions")
                .font(.headline)
            Spacer()
            Button {
                Task { await vm.load(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Refresh actions")
        }
    }
}

// MARK: - Action Card -----------------------------------------------------------
struct ActionCardView: View {
    let card: ActionCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            UrgencyChip(urgency: card.urgency)

            HStack(alignment: .top, spacing: 12) {
                categoryIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text(card.rationale)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if !card.tags.isEmpty {
                ActionTagChipsView(tags: card.tags)
            }
        }
        .padding()
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(borderOverlay)
        .shadow(color: card.category == .boost ? .white.opacity(0.3) : .clear,
                radius: card.category == .boost ? 4 : 0)
    }

    private var background: Color {
        switch card.urgency {
        case .low:      return Color.gray.opacity(0.1)
        case .moderate: return categoryTint.opacity(0.2)
        case .high:     return categoryTint.opacity(0.25)
        }
    }

    private var categoryTint: Color {
        switch card.category {
        case .boost:   return .yellow
        case .balance: return .blue
        case .replan:  return .purple
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 16)
            .stroke(categoryTint.opacity(card.urgency == .high ? 0.9 : 0), lineWidth: 2)
    }

    private var categoryIcon: some View {
        Circle()
            .fill(categoryTint.opacity(0.3))
            .frame(width: 34, height: 34)
            .overlay(
                Image(systemName: sfSymbol(for: card.category))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            )
    }

    private func sfSymbol(for cat: ActionCategory) -> String {
        switch cat {
        case .boost:   return "bolt.fill"
        case .balance: return "wind"
        case .replan:  return "calendar.badge.clock"
        }
    }
}

// MARK: - Tags ------------------------------------------------------------------
struct ActionTagChipsView: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                        .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Urgency Chip -----------------------------------------------------------
struct UrgencyChip: View {
    let urgency: ActionUrgencyLevel

    var body: some View {
        Text(label)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bg)
            .clipShape(Capsule())
    }

    private var label: String {
        switch urgency {
        case .low: "Low Priority"
        case .moderate: "Recommended"
        case .high: "High Priority"
        }
    }

    private var bg: Color {
        switch urgency {
        case .low: .gray.opacity(0.15)
        case .moderate: .accentColor.opacity(0.2)
        case .high: .red.opacity(0.25)
        }
    }
}

