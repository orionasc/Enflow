import SwiftUI

/// Card-like selector for an energy level.
private struct EnergyLevelCard: View {
    let level: EnergyLevel
    @Binding var selection: EnergyLevel?

    private var isSelected: Bool { selection == level }
    private var color: Color { energyColor(for: level) }

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selection = isSelected ? nil : level
            }
        }) {
            VStack(spacing: 6) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(color)
                    .scaleEffect(isSelected ? 1.1 : 1)
                    .shadow(color: color.opacity(isSelected ? 0.8 : 0), radius: isSelected ? 8 : 0)
                Text(level.label)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 2)
            )
            .scaleEffect(isSelected ? 1.05 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(isSelected ? 1 : 0), lineWidth: 2)
                    .shadow(color: color.opacity(isSelected ? 0.7 : 0), radius: isSelected ? 6 : 0)
            )
        }
        .buttonStyle(.plain)
    }
}

struct DailyFeedbackCard: View {
    @State private var energyLevel: EnergyLevel? = nil
    @State private var note = ""
    @State private var showToast = false
    @FocusState private var noteFocused: Bool
    @ObservedObject private var store = FeedbackStore.shared

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var submitColor: Color { energyColor(for: energyLevel ?? .moderate) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How did today feel overall?")
                .font(.headline)

            HStack(spacing: 16) {
                EnergyLevelCard(level: .high, selection: $energyLevel)
                EnergyLevelCard(level: .moderate, selection: $energyLevel)
                EnergyLevelCard(level: .low, selection: $energyLevel)
            }

            TextField("Add optional notes about today...", text: $note)
                .padding(10)
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentColor.opacity(noteFocused ? 1 : 0), lineWidth: 2)
                        .shadow(color: Color.accentColor.opacity(noteFocused ? 0.7 : 0), radius: noteFocused ? 6 : 0)
                )
                .focused($noteFocused)

            Button(action: submit) {
                Label("Submit", systemImage: "paperplane.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(submitColor)
                    )
                    .foregroundColor(.black)
            }
            .buttonStyle(.scaling)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        )
        .overlay(alignment: .top) {
            if showToast {
                Text("Feedback saved!")
                    .font(.footnote.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showToast = false }
                        }
                    }
            }
        }
    }

    private func submit() {
        let entry = DailyFeedback(id: UUID(),
                                  date: today,
                                  energyLevel: energyLevel,
                                  note: note.isEmpty ? nil : note)
        store.save(entry)
        Haptics.play(.soft)
        withAnimation { showToast = true }
        energyLevel = nil
        note = ""
        noteFocused = false
    }
}

private func energyColor(for level: EnergyLevel) -> Color {
    switch level {
    case .high: return ColorPalette.color(for: 90)
    case .moderate: return ColorPalette.color(for: 60)
    case .low: return ColorPalette.color(for: 20)
    }
}
