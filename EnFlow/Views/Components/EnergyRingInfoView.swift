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
                .cornerRadius(20)
                .padding()
            }
            .navigationTitle("Your Energy Score")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showMore) { NavigationStack { MeetSolView() } }
            .enflowBackground()
        }
    }

    private var ringStates: some View {
        HStack(spacing: 20) {
            ringExample(score: 25, label: "Low")
            ringExample(score: 55, label: "Moderate")
            ringExample(score: 78, label: "High")
            ringExample(score: 95, label: "Super")
        }
        .frame(maxWidth: .infinity)
    }

    private func ringExample(score: Double, label: String) -> some View {
        VStack(spacing: 4) {
            EnergyRingView(score: score, size: 60, showInfoButton: false)
            Text(label)
                .font(.caption)
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
