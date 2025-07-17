//  SuggestedPrioritiesView.swift
//  EnFlow
//
//  Rev. 2025-06-17 Suggested priorities cards with GPT integration.

import SwiftUI

// MARK: - Card Subviews -------------------------------------------------------

private struct PriorityCardHeaderView: View {
    let urgency: PriorityUrgencyLevel
    var body: some View {
        HStack {
            Text(urgency.label)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(headerBackground)
                .clipShape(Capsule())
            Spacer()
        }
    }

    private var headerBackground: some View {
        switch urgency {
        case .low:       Color.gray.opacity(0.15)
        case .moderate:  Color.accentColor.opacity(0.2)
        case .high:      Color.red.opacity(0.25)
        }
    }
}

private struct PriorityCardBodyView: View {
    let template: PriorityTemplate
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(color(for: template).opacity(0.35))
                    .frame(width: 34, height: 34)
                    .blur(radius: 1)

                Image(systemName: template.sfSymbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(iconColor(for: template))
                    .shadow(color: iconColor(for: template).opacity(0.6), radius: 3)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                if !bodyText.isEmpty {
                    Text(bodyText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func color(for template: PriorityTemplate) -> Color {
        switch template {
        case .focus:       return Color.blue
        case .movement:    return Color.orange
        case .rest:        return Color.indigo
        case .planning:    return Color.pink
        case .mindfulness: return Color.purple
        }
    }

    private func iconColor(for template: PriorityTemplate) -> Color { color(for: template) }
}

private struct PriorityCardTagList: View {
    let tags: [String]
    var body: some View {
        if tags.isEmpty { EmptyView() } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tags, id: \"self\") { tag in
                        RationaleChip(text: tag)
                    }
                }
            }
        }
    }
}

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
    let bodyLines = parts.dropFirst().joined(separator: " \n")
    let tint = color(for: p.template)

    VStack(alignment: .leading, spacing: 12) {
        PriorityCardHeaderView(urgency: p.urgency)
        PriorityCardBodyView(template: p.template, title: titleLine, bodyText: bodyLines)
        PriorityCardTagList(tags: p.rationaleTags)
    }
    .cardStyle(tint: p.urgency == .low ? 40 : 65)
    .background(
        RoundedRectangle(cornerRadius: 16)
            .fill(tint.opacity(p.urgency == .low ? 0.1 : 0.15))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 16)
            .stroke(p.urgency == .high ? tint : .clear, lineWidth: p.urgency == .high ? 2 : 0)
            .shadow(color: tint.opacity(p.urgency == .high ? 0.8 : 0), radius: p.urgency == .high ? 6 : 0)
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
