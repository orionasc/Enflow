//  SuggestedPrioritiesView.swift
//  EnFlow
//
//  Rev. 2025-06-17 Suggested priorities cards with GPT integration.

import SwiftUI

/// Context passed in from DashboardView to drive GPT suggestions.
struct SuggestedPriorityContext {
  let overallEnergy: Double  // 0…1
  let threePart: EnergyForecastModel.EnergyParts  // normalized 0…1
  let sleepScore: Double  // 0…1
  let hrvScore: Double  // 0…1
  let calendarEvents: [CalendarEvent]
  let nextFreeBlocks: [DateInterval]
}

/// GPT-powered priority suggestions rendered as glossy cards.
struct SuggestedPrioritiesView: View {

  // ───────── Inputs ─────────────────────────────────────────────
  @AppStorage("insightVariety") private var insightVariety: Double = 0.5
  let context: SuggestedPriorityContext

  // ───────── State ──────────────────────────────────────────────
  @StateObject private var vm = SuggestedPrioritiesVM()
  @State private var selectedForExplain: PriorityResult?
  @State private var showInfo = false

  // ───────── View ───────────────────────────────────────────────
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Suggested Priorities")
          .font(.headline)
        Spacer()
        Button { showInfo = true } label: {
          Image(systemName: "info.circle")
            .font(.headline)
        }
        .buttonStyle(.embossedInfo)
      }
      .padding(.bottom, 4)

      if vm.isLoading {
        ProgressView()
          .progressViewStyle(.circular)
          .frame(maxWidth: .infinity, alignment: .center)

      } else if !vm.priorities.isEmpty {
        ForEach(vm.priorities) { p in
          ZStack(alignment: .topTrailing) {
            suggestionCard(for: p)
              .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button {
                  vm.pin(p)
                } label: {
                  Label("Pin", systemImage: "pin.fill")
                }
                Button {
                  vm.snooze(p)
                } label: {
                  Label("Snooze", systemImage: "clock.fill")
                }
                Button {
                  vm.dismiss(p)
                } label: {
                  Label("Dismiss", systemImage: "xmark.circle")
                }
              }
              .contextMenu {
                Button("Pin") { vm.pin(p) }
                Button("Snooze") { vm.snooze(p) }
                Button("Dismiss") { vm.dismiss(p) }
              }

            Button {
              selectedForExplain = p
            } label: {
              Image(systemName: "info.circle")
                .font(.headline)
                // Smaller padding so the embossed background matches other info buttons
                .padding(4)
            }
            .buttonStyle(.embossedInfo)
          }
        }
      } else {
        Text(vm.errorText ?? "AI suggestions unavailable.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .task(id: contextHash) { await vm.refresh() }
    .onAppear { if vm.priorities.isEmpty { Task { await vm.refresh() } } }
    .animation(.easeInOut, value: vm.priorities)
    .sheet(isPresented: $showInfo) {
      SuggestedPrioritiesInfoView()
    }
    .sheet(item: $selectedForExplain) { p in
        let parts = p.text.components(separatedBy: .newlines)
        let header = parts.first ?? p.text
        let bullets = p.rationale.components(separatedBy: "\n")

        ExplainSheetView(
            header: header,
            bullets: bullets,
            timestamp: Date(),
            template: p.template
        )
    }
  }

  // ───────── Card UI ────────────────────────────────────────────
  @ViewBuilder
  private func suggestionCard(for p: PriorityResult) -> some View {
    let parts = p.text.components(separatedBy: .newlines)
    let titleLine = parts.first ?? p.text
    let bodyLines: String = {
      if parts.count > 1 { return parts.dropFirst().joined(separator: "\n") }
      if let idx = p.text.firstIndex(where: { ".:?!".contains($0) }) {
        return String(p.text[p.text.index(after: idx)...])
          .trimmingCharacters(in: .whitespaces)
      }
      return ""
    }()

    let tint = color(for: p.template)

    VStack(alignment: .leading, spacing: 8) {
      Text("Based on today’s recovery + forecast")
        .font(.caption)
        .foregroundStyle(.secondary)

      HStack(alignment: .top, spacing: 12) {
        ZStack {
          Circle()
            .fill(tint.opacity(0.35))
            .frame(width: 34, height: 34)
            .blur(radius: 1)

          Image(systemName: p.template.sfSymbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(iconColor(for: p.template))
            .shadow(color: iconColor(for: p.template).opacity(0.6), radius: 3)
        }
        .frame(width: 34, height: 34)

        VStack(alignment: .leading, spacing: 4) {
          Text(titleLine)
            .font(.headline)
            .fontWeight(.semibold)
          if !bodyLines.isEmpty {
            Text(bodyLines)
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        Spacer(minLength: 0)
      }
    }
    .cardStyle(tint: 65)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(tint.opacity(0.15))
    )
  }

  // ───────── Helpers ─────────────────────────────────────────────
  private var contextHash: Int {
    context.overallEnergy.hashValue ^ Int(context.sleepScore * 1_000)
  }

  // Color helpers -------------------------------------------------
  private func color(for template: PriorityTemplate) -> Color {
    switch template {
    case .focus:       return Color.blue
    case .movement:    return Color.orange
    case .rest:        return Color.indigo
    case .planning:    return Color.pink
    case .mindfulness: return Color.purple
    }
  }

  private func iconColor(for template: PriorityTemplate) -> Color {
    color(for: template)
  }
}
