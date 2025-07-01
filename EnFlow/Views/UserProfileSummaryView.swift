import SwiftUI

/// Redesigned User tab acting as a personal hub for energy behaviour.
struct UserProfileSummaryView: View {
    @State private var profile: UserProfile = UserProfileStore.load()
    @State private var showEdit = false
    @State private var showStory = false
    @State private var storyText = ""
    @State private var isLoadingStory = false
    @State private var showDebug = false
    @ObservedObject private var dataMode = DataModeManager.shared

    // Goal checkboxes persisted via AppStorage
    @AppStorage("goal_sleepConsistency") private var goalSleep = false
    @AppStorage("goal_reduceDips") private var goalDips = false
    @AppStorage("goal_boostMorning") private var goalMorning = false
    @AppStorage("goal_reduceCaffeine") private var goalCaffeine = false
    @AppStorage("goal_increaseAccuracy") private var goalAccuracy = false

    // 7-day averages
    @State private var avgScore: Double? = nil
    @State private var avgParts: EnergyForecastModel.EnergyParts? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                overviewCards
                energyProfile
                goalsSection
                storySection
                debugSection
            }
            .padding()
        }
        .navigationTitle("User")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") { showEdit = true }
            }
        }
        .task { await loadAverages() }
        .sheet(isPresented: $showEdit, onDismiss: { profile = UserProfileStore.load(); Task { await loadAverages() } }) {
            UserProfileQuizView()
        }
        .sheet(isPresented: $showStory) { storyModal }
        .enflowBackground()
    }

    // MARK: – Sections
    private var headerSection: some View {
        VStack {
            ZStack {
                if let sc = avgScore {
                    Circle()
                        .fill(ColorPalette.color(for: sc))
                        .blur(radius: 20)
                        .opacity(0.6)
                        .frame(width: 140, height: 140)
                }
                EnergyRingView(score: avgScore, size: 120, showInfoButton: false)
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.white)
            }
            .onTapGesture { showEdit = true }
        }
    }

    private var overviewCards: some View {
        VStack(spacing: 16) {
            sleepCard
            caffeineCard
            exerciseCard
        }
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Wake: \(time(profile.typicalWakeTime))", systemImage: "sunrise.fill")
            Label("Bed: \(time(profile.typicalSleepTime))", systemImage: "moon.fill")
            Label("Chronotype: \(profile.chronotype.rawValue.capitalized)", systemImage: "clock")
            Toggle("Sleep Aid", isOn: $profile.usesSleepAid).onChange(of: profile.usesSleepAid) { _ in save() }
            Toggle("Screens Before Bed", isOn: $profile.screensBeforeBed).onChange(of: profile.screensBeforeBed) { _ in save() }
            Toggle("Regular Meals", isOn: $profile.mealsRegular).onChange(of: profile.mealsRegular) { _ in save() }
        }
        .cardStyle()
    }

    private var caffeineCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Intake: \(profile.caffeineMgPerDay)mg", systemImage: "cup.and.saucer.fill")
            Toggle("Morning", isOn: $profile.caffeineMorning).onChange(of: profile.caffeineMorning) { _ in save() }
            Toggle("Afternoon", isOn: $profile.caffeineAfternoon).onChange(of: profile.caffeineAfternoon) { _ in save() }
            Toggle("Evening", isOn: $profile.caffeineEvening).onChange(of: profile.caffeineEvening) { _ in save() }
            Text("1 cup ≈ 95mg")
                .font(.footnote).foregroundColor(.secondary)
            Text("Afternoon caffeine correlated with sleep disruption")
                .font(.footnote).foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper("Weekly Goal: \(profile.exerciseFrequency)x", value: $profile.exerciseFrequency, in: 0...14)
                .onChange(of: profile.exerciseFrequency) { _ in save() }
            Text("You're meeting your target!")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var energyProfile: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let parts = avgParts {
                ThreePartForecastView(parts: parts)
                let best = bestWindow(from: parts)
                Text("Best energy in \(best)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ThreePartForecastView(parts: nil)
            }
        }
        .cardStyle()
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Improve Sleep Consistency", isOn: $goalSleep)
            Toggle("Reduce Afternoon Dips", isOn: $goalDips)
            Toggle("Boost Morning Energy", isOn: $goalMorning)
            Toggle("Reduce Caffeine Reliance", isOn: $goalCaffeine)
            Toggle("Increase Prediction Accuracy", isOn: $goalAccuracy)
        }
        .cardStyle()
    }

    private var storySection: some View {
        Button("View My Energy Story") { Task { await loadStory() } }
            .buttonStyle(.borderedProminent)
    }

    private var storyModal: some View {
        NavigationStack {
            ScrollView {
                if isLoadingStory {
                    ProgressView().padding()
                } else {
                    Text(storyText).padding()
                }
            }
            .navigationTitle("Energy Story")
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { showStory = false } } }
            .presentationDetents([.medium, .large])
        }
    }

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button("Toggle Developer Info") { withAnimation { showDebug.toggle() } }
            if showDebug {
                Toggle("Use Simulated Data", isOn: Binding(
                    get: { dataMode.isSimulated() },
                    set: { DataModeManager.shared.setMode($0 ? .simulated : .real) }
                ))
                Text(profile.debugSummary())
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if let acc = ForecastCache.shared.recentAccuracy(days: 7) {
                    Text("7d forecast accuracy: \(Int(acc * 100))%")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            NavigationLink { DataView() } label: { Label("Data", systemImage: "chart.bar") }
            NavigationLink { MeetSolView() } label: { Label("Sol: Our Energy Model", systemImage: "sun.max.fill") }
        }
        .cardStyle()
    }

    // MARK: – Helpers
    private func time(_ d: Date) -> String {
        let fmt = DateFormatter(); fmt.timeStyle = .short
        return fmt.string(from: d)
    }

    private func save() {
        profile.lastUpdated = Date()
        UserProfileStore.save(profile)
    }

    private func bestWindow(from parts: EnergyForecastModel.EnergyParts) -> String {
        let maxVal = max(parts.morning, parts.afternoon, parts.evening)
        switch maxVal {
        case parts.morning: return "Morning"
        case parts.afternoon: return "Afternoon"
        default: return "Evening"
        }
    }

    @MainActor
    private func loadAverages() async {
        let cal = Calendar.current
        let health = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 7)
        let start = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) ?? Date()
        let events = await CalendarDataPipeline.shared.fetchEvents(start: start, end: Date())
        var scores: [Double] = []
        var m: [Double] = []
        var a: [Double] = []
        var e: [Double] = []
        let model = EnergyForecastModel()
        for i in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: Date())) else { continue }
            let summary = UnifiedEnergyModel.shared.summary(for: day, healthEvents: health, calendarEvents: events, profile: profile)
            scores.append(summary.overallEnergyScore)
            if let part = model.threePartEnergy(for: day, health: health, events: events, profile: profile) {
                m.append(part.morning); a.append(part.afternoon); e.append(part.evening)
            }
        }
        avgScore = scores.isEmpty ? nil : scores.reduce(0, +) / Double(scores.count)
        if !m.isEmpty {
            avgParts = EnergyForecastModel.EnergyParts(
                morning: m.reduce(0, +)/Double(m.count),
                afternoon: a.reduce(0, +)/Double(a.count),
                evening: e.reduce(0, +)/Double(e.count))
        }
    }

    private func loadStory() async {
        showStory = true
        isLoadingStory = true
        let prompt = """
Generate a friendly but insightful summary of the user's weekly energy profile based on the following input:
- Chronotype: \(profile.chronotype.rawValue)
- Wake/Sleep Time: \(time(profile.typicalWakeTime)) - \(time(profile.typicalSleepTime))
- Exercise frequency: \(profile.exerciseFrequency)
- Caffeine habits: \(profile.caffeineMgPerDay)mg — morning: \(profile.caffeineMorning), afternoon: \(profile.caffeineAfternoon), evening: \(profile.caffeineEvening)
- Most energetic time of day (user-reported): \(profile.chronotype.rawValue)
- Weekly forecasted energy scores (morning/afternoon/evening)
- Weekly calculated energy scores (morning/afternoon/evening)
- System-generated insights:
"""
        do {
            let text = try await OpenAIManager.shared.generateInsight(prompt: prompt)
            storyText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            storyText = "Unable to load story."
        }
        isLoadingStory = false
    }
}

#Preview {
    NavigationStack { UserProfileSummaryView() }
}
