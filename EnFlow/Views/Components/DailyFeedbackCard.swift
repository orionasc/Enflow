import SwiftUI

struct EnergyLevelToggle: View {
    let level: EnergyLevel
    @Binding var selection: EnergyLevel?

    var isSelected: Bool { selection == level }

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = isSelected ? nil : level
            }
        }) {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    ForEach(0..<level.rawValue, id: \.self) { _ in
                        Image(systemName: "bolt.fill")
                    }
                }
                .font(.title2)
                .foregroundColor(isSelected ? .yellow : .gray)
                .scaleEffect(isSelected ? 1.2 : 1.0)
                .padding(12)
                .background(Circle().fill(isSelected ? Color.yellow.opacity(0.25) : Color.gray.opacity(0.15)))
                Text(level.label).font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DailyFeedbackCard: View {
    @State private var energyLevel: EnergyLevel? = nil
    @State private var note = ""
    @State private var saved = false
    @ObservedObject private var store = FeedbackStore.shared

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did today feel overall?")
                .font(.headline)

            HStack(spacing: 24) {
                EnergyLevelToggle(level: .high, selection: $energyLevel)
                EnergyLevelToggle(level: .moderate, selection: $energyLevel)
                EnergyLevelToggle(level: .low, selection: $energyLevel)
            }

            TextField("Add a note...", text: $note)
                .padding(8)
                .background(.ultraThinMaterial)
                .cornerRadius(8)

            Button("Submit") {
                let entry = DailyFeedback(id: UUID(),
                                          date: today,
                                          energyLevel: energyLevel,
                                          note: note.isEmpty ? nil : note)
                store.save(entry)
                withAnimation { saved = true }
                energyLevel = nil; note = ""
            }
            .buttonStyle(.borderedProminent)

            if saved {
                Text("Saved!")
                    .font(.footnote)
                    .foregroundColor(.green)
            }
        }
        .cardStyle(tint: 60)
    }
}
