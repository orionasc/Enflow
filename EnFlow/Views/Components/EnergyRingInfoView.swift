import SwiftUI

struct EnergyRingInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showMore = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("The ring represents your current day’s composite energy score, a weighted blend of mental and physical readiness.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ringStates
                    Text("Sol calculates this score from:")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    metricBullets
                    Button("Learn how Sol calculates energy") { showMore = true }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .padding()
            }
            .navigationTitle("Understanding Your Energy Rings")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showMore) { NavigationStack { MeetSolView() } }
        }
    }

    private var ringStates: some View {
        VStack(spacing: 16) {
            ringRow(score: 25, title: "Low (0–40)", description: "Ring appears red/orange, sparse fill.")
            ringRow(score: 55, title: "Moderate (40–65)", description: "Yellow, steady glow.")
            ringRow(score: 78, title: "High (65–90)", description: "Vibrant green with pulse.")
            ringRow(score: 95, title: "Supercharged (90–100)", description: "Blue-tinted white with glow.")
        }
    }

    private func ringRow(score: Double, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            EnergyRingView(score: score)
                .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(description).font(.subheadline).foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var metricBullets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("HRV (Heart Rate Variability) — Tracks your body’s readiness and recovery state", systemImage: "heart.fill")
            Label("Resting Heart Rate — Reflects baseline cardiovascular stress", systemImage: "waveform.path.ecg")
            Label("Sleep Efficiency — Measures how much of your sleep time was restorative", systemImage: "bed.double.fill")
            Label("Sleep Latency — How quickly you fall asleep (shorter = better recovery)", systemImage: "zzz")
            Label("Deep Sleep Duration — Critical for physical repair", systemImage: "moon.zzz.fill")
            Label("REM Sleep Duration — Tied to focus, memory, and mood", systemImage: "eye.fill")
            Label("Active Energy Burned — Tracks daily physical exertion", systemImage: "flame.fill")
            Label("Step Count — Helps gauge movement load", systemImage: "figure.walk")
            Label("Respiratory Rate — Adds physiological context", systemImage: "lungs.fill")
            Label("Oxygen Saturation — Affects fatigue and performance potential", systemImage: "drop.fill")
            Label("VO₂ Max — Represents cardiovascular efficiency", systemImage: "figure.mind.and.body")
            Label("Apple Exercise Time — Movement minutes per day", systemImage: "figure.run")
            Label("Mindfulness Minutes — Indicates mental recovery effort", systemImage: "brain.head.profile")
        }
        .font(.body)
        .labelStyle(.titleAndIcon)
    }
}

#Preview {
    EnergyRingInfoView()
}
