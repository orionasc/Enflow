import SwiftUI

struct FeedbackToggle: View {
    let icon: String
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isOn.toggle() } }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isOn ? .yellow : .gray)
                    .scaleEffect(isOn ? 1.2 : 1.0)
                    .padding(12)
                    .background(Circle().fill(isOn ? Color.yellow.opacity(0.25) : Color.gray.opacity(0.15)))
                Text(label).font(.caption)
            }
        }
        .buttonStyle(.plain)
    }
}

struct DailyFeedbackCard: View {
    @State private var energy = false
    @State private var stress = false
    @State private var sleep = false
    @State private var note = ""
    @State private var saved = false
    @ObservedObject private var store = FeedbackStore.shared

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How did today feel overall?")
                .font(.headline)

            HStack(spacing: 24) {
                FeedbackToggle(icon: "bolt.fill", label: "Energy", isOn: $energy)
                FeedbackToggle(icon: "exclamationmark.triangle.fill", label: "Stress", isOn: $stress)
                FeedbackToggle(icon: "bed.double.fill", label: "Sleep", isOn: $sleep)
            }

            TextField("Add a note...", text: $note)
                .textFieldStyle(.roundedBorder)

            Button("Submit") {
                let entry = DailyFeedback(id: UUID(),
                                          date: today,
                                          feltHighEnergy: energy,
                                          feltStressed: stress,
                                          feltWellRested: sleep,
                                          note: note.isEmpty ? nil : note)
                store.save(entry)
                withAnimation { saved = true }
                energy = false; stress = false; sleep = false; note = ""
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
