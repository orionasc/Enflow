import SwiftUI

struct MeetSolView: View {
    @State private var showMetrics = false
    @State private var pulse = false
    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                introSection
                calcSection
                forecastSection
                calendarSection
                personalizeSection
                footerSection
            }
            .padding()
        }
        .navigationTitle("Meet Sol")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showMetrics) { MetricDetailsView() }
        .enflowBackground()
    }

    // MARK: Intro
    private var introSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [Color.yellow.opacity(0.6), Color.orange.opacity(0.3)],
                        center: .center,
                        startRadius: 40,
                        endRadius: 180
                    )
                )
            VStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.yellow)
                    .scaleEffect(pulse ? 1.1 : 0.9)
                    .opacity(pulse ? 1 : 0.7)
                    .onAppear { withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { pulse = true } }
                Text("Meet Sol")
                    .font(.largeTitle.bold())
                Text("Your Energy Intelligence Engine")
                    .font(.title3)
                    .foregroundColor(.orange)
                Text("Sol is the engine that powers your energy forecasts. It takes your real-world data and transforms it into actionable guidance, helping you understand when and why your energy rises or dips.")
                    .font(.body)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }

    // MARK: Calculation
    private var calcSection: some View {
        sectionCard(title: "How Your Daily Energy is Calculated") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sol combines your biometric and behavioral data into a score from 0–100. Here’s what it uses:")
                    .font(.body)
                metricBullets
                Text("Sol creates a moment-to-moment energy curve using this full dataset — not just sleep or steps.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Button("Learn More") { showMetrics = true }
                    .padding(.top, 4)
            }
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

    // MARK: Forecast
    private var forecastSection: some View {
        sectionCard(title: "How Sol Predicts Your Energy") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sol doesn’t just reflect your current energy — it forecasts what’s ahead.")
                    .font(.body)
                EnergyLineChartView(values: sampleWave)
                    .frame(height: 60)
                VStack(alignment: .leading, spacing: 8) {
                    Label("Uses your past 7–14 days of biometric data", systemImage: "clock.arrow.circlepath")
                    Label("Applies circadian modeling to adjust by time of day", systemImage: "sunrise.fill")
                    Label("Weighs your calendar schedule to detect workload spikes", systemImage: "calendar")
                    Label("Adjusts for patterns in sleep, activity, and recovery trends", systemImage: "waveform.path.ecg")
                    Label("If your data is sparse, Sol marks forecasts as lower confidence", systemImage: "exclamationmark.triangle.fill")
                }
                .font(.body)
                .labelStyle(.titleAndIcon)
            }
        }
    }

    private var sampleWave: [Double] {
        [0.3,0.5,0.7,0.9,0.8,0.6,0.4,0.3,0.2,0.3,0.5,0.8,0.9,0.7,0.5,0.4,0.3,0.5,0.7,0.9,0.8,0.6,0.4,0.2]
    }

    // MARK: Calendar
    private var calendarSection: some View {
        sectionCard(title: "How Calendar Patterns Shape Forecasts") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sol connects your energy to your schedule — so your week works with you, not against you.")
                    .font(.body)
                TabView {
                    Text("Energy dips after 3+ back-to-back meetings")
                    Text("You perform best when workouts are done before 7 PM")
                    Text("Recovery improves after social breaks mid-week")
                }
                .tabViewStyle(.page)
                .frame(height: 50)
                Text("These patterns are generated locally — your calendar data is never shared.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Personalize
    private var personalizeSection: some View {
        sectionCard(title: "Personalize Your Forecasts") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sol is smarter when it knows your habits. Caffeine, wake time, sleep routine — they all matter.")
                    .font(.body)
                NavigationLink("Update Your Profile") {
                    UserProfileQuizView()
                }
                .buttonStyle(.borderedProminent)
                Text("You can retake your profile quiz anytime to reflect new habits.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Footer
    private var footerSection: some View {
        sectionCard(title: "") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sol is your intelligent companion for energy awareness and scheduling alignment. The more it learns, the better your days can feel.")
                    .font(.body)
                Text("Last recalibrated: June 25, 2025")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Helpers
    @ViewBuilder
    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !title.isEmpty {
                Text(title)
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            content()
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.ultraThinMaterial))
    }
}

private struct MetricDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            List {
                Section {
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
            }
            .navigationTitle("Energy Metrics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

#Preview {
    NavigationView { MeetSolView() }
}
