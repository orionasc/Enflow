import SwiftUI

/// Redesigned User tab acting as a personal hub for energy behaviour.
struct UserProfileSummaryView: View {
    @State private var profile: UserProfile = UserProfileStore.load()
    @State private var storyText = ""
    @State private var isLoadingStory = false
    @State private var showDebug = false
    @State private var showInfoAlert = false
    @State private var infoMessage = ""
    @ObservedObject private var dataMode = DataModeManager.shared

    // Goal checkboxes persisted via AppStorage
    @AppStorage("goal_sleepConsistency") private var goalSleep = false
    @AppStorage("goal_reduceDips") private var goalDips = false
    @AppStorage("goal_boostMorning") private var goalMorning = false
    @AppStorage("goal_reduceCaffeine") private var goalCaffeine = false
    @State private var pulseSol = false
    @State private var showWritingIndicator = false

    // 7-day averages
    @State private var avgScore: Double? = nil
    @State private var avgParts: EnergyForecastModel.EnergyParts? = nil
    @State private var daysOfData: Int = 0

    /// Classification label + icon based on the average score
    private var classification: (label: String, icon: String) {
        guard let score = avgScore else { return ("--", "questionmark") }
        switch score {
        case ..<60:  return ("Needs Work", "exclamationmark.triangle.fill")
        case 60..<70: return ("Moderate", "figure.walk.circle.fill")
        case 70..<80: return ("Great", "hand.thumbsup.fill")
        case 80..<90: return ("Excellent", "star.fill")
        default:      return ("Superhuman", "bolt.fill")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                overviewCards
                sectionTitle("Energy Score", info: "Your daily average, based on sleep, movement, and recovery.")
                energyProfile
                sectionTitle("Goals", info: "Choose what you'd like to improve.")
                goalsSection
                sectionTitle("Your Energy Story", info: "A personalized reflection of your energy patterns over time.")
                storySection
                solNotesSection
                debugSection
            }
            .padding()
        }
        .navigationTitle("User Profile")
        .task { await loadAverages() }
        .alert("Info", isPresented: $showInfoAlert, actions: {}) {
            Text(infoMessage)
        }
        .enflowBackground()
    }

    // MARK: – Sections
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your 7-Day Average Energy")
                .font(.headline)
            HStack(alignment: .center, spacing: 16) {
                ZStack {
                    if let sc = avgScore {
                        Circle()
                            .fill(ColorPalette.color(for: sc))
                            .blur(radius: 20)
                            .opacity(0.6)
                            .frame(width: 140, height: 140)
                    }
                    Image(systemName: "person.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white.opacity(0.4))
                        .zIndex(0)
                    EnergyRingView(score: avgScore, size: 120, showInfoButton: false, showValueLabel: false)
                        .zIndex(1)
                    if let sc = avgScore {
                        Text("\(Int(sc))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(
                                        RadialGradient(gradient: Gradient(colors: [Color.black.opacity(0.4), .clear]), center: .center, startRadius: 0, endRadius: 40)
                                    )
                                    .blur(radius: 2)
                            )
                            .zIndex(2)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: classification.icon)
                            .foregroundColor(ColorPalette.color(for: avgScore ?? 0))
                        Text(classification.label)
                            .font(.title3.bold())
                            .foregroundColor(ColorPalette.color(for: avgScore ?? 0))
                    }
                    Text("Based on the last week of sleep, activity and recovery.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var overviewCards: some View {
        VStack(spacing: 16) {
            sectionTitle("Sleep", info: "Edit your wake and bed times plus other habits.")
            sleepCard
            sectionTitle("Caffeine", info: "Track your daily caffeine intake.")
            caffeineCard
            sectionTitle("Activity", info: "Your weekly exercise goal.")
            exerciseCard
        }
    }

    private var sleepCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Wake Time")
                    .font(.subheadline.weight(.medium))
                Spacer()
                DatePicker("", selection: $profile.typicalWakeTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: profile.typicalWakeTime) { _ in save() }
            }
            HStack {
                Text("Bed Time")
                    .font(.subheadline.weight(.medium))
                Spacer()
                DatePicker("", selection: $profile.typicalSleepTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .onChange(of: profile.typicalSleepTime) { _ in save() }
            }
            HStack(alignment: .center) {
                Text("Peak Energy")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Picker("", selection: $profile.chronotype) {
                    ForEach(UserProfile.Chronotype.selectableCases) { c in
                        Text(c.rawValue.capitalized).tag(c)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: profile.chronotype) { _ in save() }
                Button {
                    profile.chronotype = .none
                    save()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
            Text("When do you feel you have the most energy?")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var caffeineCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Stepper(value: $profile.caffeineMgPerDay, in: 0...1000, step: 10) {
                Label("Intake: \(profile.caffeineMgPerDay)mg", systemImage: "cup.and.saucer.fill")
            }
            .onChange(of: profile.caffeineMgPerDay) { _ in save() }
            Toggle("Morning", isOn: $profile.caffeineMorning).onChange(of: profile.caffeineMorning) { _ in save() }
            Toggle("Afternoon", isOn: $profile.caffeineAfternoon).onChange(of: profile.caffeineAfternoon) { _ in save() }
            Toggle("Evening", isOn: $profile.caffeineEvening).onChange(of: profile.caffeineEvening) { _ in save() }
            Text("1 cup of coffee ≈ 95mg")
                .font(.footnote).foregroundColor(.secondary)
            Text("Afternoon caffeine correlated with sleep disruption")
                .font(.footnote).foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var exerciseCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Exercise")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Stepper(value: $profile.exerciseFrequency, in: 0...14) {
                    Text("\(profile.exerciseFrequency)x/week")
                }
                .onChange(of: profile.exerciseFrequency) { _ in save() }
            }
            Text("Consistent activity pattern")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var energyProfile: some View {
        VStack(alignment: .leading, spacing: 12) {
            ThreePartForecastView(parts: avgParts)

            if let parts = avgParts {
                Text("Best energy in \(bestWindow(from: parts))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("7-day average for each period")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .cardStyle()
    }

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Improve Sleep Consistency", isOn: $goalSleep)
            Toggle("Reduce Afternoon Dips", isOn: $goalDips)
            Toggle("Boost Morning Energy", isOn: $goalMorning)
            Toggle("Reduce Caffeine Reliance", isOn: $goalCaffeine)
        }
        .cardStyle()
    }

    private var storySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isLoadingStory {
                if showWritingIndicator {
                    Text("Still writing…")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                } else {
                    ProgressView()
                }
            } else if storyText.isEmpty {
                Text("Your story is just beginning... We’ll uncover your energy rhythm soon.")
                    .font(.body)
                    .foregroundColor(.secondary)
            } else {
                Text(verbatim: storyText)
                    .transition(.opacity)
            }
            HStack {
                Button("Refresh Story") { Task { await loadStory() } }
                    .buttonStyle(.bordered)
            }
        }
        .onAppear { if storyText.isEmpty { Task { await loadStory() } } }
        .cardStyle()
        .animation(.easeInOut, value: storyText)
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
        }
        .cardStyle()
    }

    private var solNotesSection: some View {
        VStack(spacing: 8) {
            NavigationLink(destination: MeetSolView()) {
                Label("Sol", systemImage: "sun.max.fill")
                    .font(.body.bold())
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.orange, Color.yellow]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
                    .scaleEffect(pulseSol ? 1.03 : 1)
            }
            .buttonStyle(.plain)
            .onAppear { withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { pulseSol.toggle() } }

            TextEditor(text: Binding(
                get: { profile.notes ?? "" },
                set: { profile.notes = $0; save() }
            ))
            .frame(minHeight: 80)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.3))
            )
            Text("Additional Notes for Sol")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .cardStyle(tint: 100)
    }

    // MARK: – Helpers
    private func time(_ d: Date) -> String {
        let fmt = DateFormatter(); fmt.timeStyle = .short
        return fmt.string(from: d)
    }

    private func sectionTitle(_ text: String, info: String? = nil) -> some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.title3.bold())
            if let info {
                Button {
                    infoMessage = info
                    showInfoAlert = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        daysOfData = m.count
        if m.count >= 3 {
            avgParts = EnergyForecastModel.EnergyParts(
                morning: m.reduce(0, +) / Double(m.count),
                afternoon: a.reduce(0, +) / Double(a.count),
                evening: e.reduce(0, +) / Double(e.count))
        } else {
            avgParts = nil
        }
    }

    private func loadStory() async {
        isLoadingStory = true
        showWritingIndicator = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if isLoadingStory { showWritingIndicator = true }
        }
        let prompt = """
GPT RULES:
1. Output should be engaging, mildly witty, or insightful — not just a summary of stats.
2. Highlight correlations, inconsistencies, or trends across behaviors.
3. Suggest questions or patterns the user might not have noticed.
4. Allow personality to emerge (e.g., “You seem to crash right after caffeine... suspicious.”)
5. If data is limited, reflect on potential — not absence (e.g., “Your EnFlow Energy Story is just beginning. Think of this as the prequel.”)
6. DO NOT use markdown, emojis, or bullet points. Output plain text in full sentences.
7. Be concise but not dry.
8. YOU MUST COMPLETE THE RESPONSE. DO NOT END MID-THOUGHT OR MID-SENTENCE. Make sure your output is a fully formed response, at least 3–5 paragraphs if data is available. If unsure how to end, wrap with a clean final reflection (e.g., "Let’s see how this evolves over time.")

DATA:
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
            let text = try await generateEnergyStoryWithRetry(prompt: prompt)
            storyText = text
        } catch {
            storyText = "Unable to load story."
        }
        isLoadingStory = false
        showWritingIndicator = false
    }

    /// Detect potential truncation or incomplete text
    private func isLikelyCutOff(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let minLength = 250
        let softEndings = [",", "and", "but", "or", "so", "because", "although", "if", "when", "while"]

        guard trimmed.count > 50 else { return true }

        if trimmed.count < minLength || softEndings.contains(where: { trimmed.lowercased().hasSuffix($0) }) {
            return true
        }

        return false
    }

    /// Re-request the GPT story if the response seems truncated
    private func generateEnergyStoryWithRetry(prompt: String, maxAttempts: Int = 3) async throws -> String {
        var attempt = 0
        var result: String = ""

        repeat {
            attempt += 1
            let rawText = try await OpenAIManager.shared.generateInsight(prompt: prompt)
            let cleaned = rawText.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            result = cleaned

            if !isLikelyCutOff(cleaned) {
                return cleaned
            }

        } while attempt < maxAttempts

        return result
    }
}

#Preview {
    NavigationStack { UserProfileSummaryView() }
}
