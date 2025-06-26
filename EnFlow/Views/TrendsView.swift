import SwiftUI
import Charts
import Foundation

enum TrendsPeriod: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case sixWeeks = "6 Weeks"
    var id: String { rawValue }
}

/// TrendsView shows energy trends and an AI-generated weekly YAML summary with full control over reloads and formatting.
struct TrendsView: View {
    @State private var period: TrendsPeriod = .weekly

    @State private var summaries: [DayEnergySummary] = []
    @State private var forecastSummaries: [DayEnergySummary] = []
    @State private var accuracy: Double = 0.0
    @State private var insightTags: [String] = []
    @State private var insightText: String = ""
    @State private var gptSummary: String = ""
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var selectedEventDate: Date? = nil
    @State private var animatePulse = false
    // Use a vivid blue so the forecast line is clearly distinguished
    private let forecastColor = Color.blue
    /// Fixed colour scale so Charts doesn't override our explicit styles
    private let seriesColors: KeyValuePairs<String, Color> = [
        "Calculated": .yellow,
        "Forecasted": .blue
    ]

    private var highlightedSummary: AttributedString {
        var result = AttributedString()
        var remaining = gptSummary[...]
        while let start = remaining.range(of: "<highlight>") {
            let before = remaining[..<start.lowerBound]
            result.append(AttributedString(String(before)))
            remaining = remaining[start.upperBound...]
            guard let end = remaining.range(of: "</highlight>") else { break }
            var highlighted = AttributedString(String(remaining[..<end.lowerBound]))
            highlighted.foregroundColor = .yellow
            result.append(highlighted)
            remaining = remaining[end.upperBound...]
        }
        result.append(AttributedString(String(remaining)))
        return result
    }

    private var forecastAvailable: Bool {
        !forecastSummaries.isEmpty && forecastSummaries.count == summaries.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Sub-navigation picker
                Picker("", selection: $period) {
                    ForEach(TrendsPeriod.allCases) { p in Text(p.rawValue).tag(p) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Energy chart title
                Text("Energy Over Time")
                    .font(.headline)
                    .foregroundColor(.yellow)
                    .padding(.horizontal)

                // Dual-line chart (Actual = yellow, Forecast = blue)
                energyChart

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: 24, y: 0)) }
                            .stroke(forecastColor, style: StrokeStyle(lineWidth: 2, dash: forecastAvailable ? [] : [5,3]))
                            .frame(height: 2)
                        Text("Forecasted").foregroundColor(forecastColor)
                    }
                    HStack(spacing: 4) {
                        Path { p in p.move(to: .zero); p.addLine(to: CGPoint(x: 24, y: 0)) }
                            .stroke(Color.yellow, lineWidth: 2)
                            .frame(height: 2)
                        Text("Calculated").foregroundColor(.yellow)
                    }
                }
                .font(.caption)
                .padding(.horizontal)

                if !forecastAvailable {
                    Text("You haven't used the app for long enough for this feature")
                        .font(.caption.italic())
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }

                // Main energy toggle icon
                HStack { Spacer()
                    Button(action: {}) {
                        Circle().fill(Color.yellow.opacity(0.2)).frame(width: 48, height: 48)
                            .overlay(Image(systemName: "bolt.fill").font(.title2).foregroundColor(.yellow))
                    }
                    Spacer()
                }
                .padding(.vertical, 4)

                // Prediction accuracy bar
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prediction Accuracy").font(.headline).padding(.horizontal)
                    HStack {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.gray.opacity(0.2)).frame(height: 8)
                                Capsule().fill(Color.yellow).frame(width: geo.size.width * accuracy, height: 8)
                            }
                        }
                        .frame(height: 8)

                        Text("\(Int(accuracy * 100))%")
                            .font(.subheadline.bold())
                            .foregroundColor(.yellow)
                    }
                    .padding(.horizontal)
                }
                if accuracy == 0 {
                    Text("Not enough prediction data to make accurate assessment")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }

                // Energy insights
                EnergyInsightsCard(tags: insightTags, text: insightText, forecastColor: forecastColor)
                    .padding(.horizontal)

                // GPT Weekly Summary with separate reload
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("GPT Weekly Summary")
                            .font(.headline)
                        Spacer()
                        // Reload only GPT summary
                        Button(action: { Task { await loadGPTSummary() } }) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.title2)
                                .foregroundColor(.yellow)
                        }
                        .accessibilityLabel("Reload GPT summary")
                    }
                    .padding(.horizontal)

                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(radius: 4)
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(highlightedSummary)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.white)
                                .padding()
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .onTapGesture { handleEventTap(in: gptSummary) }
                        }
                        .frame(maxHeight: 300)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 30)
            }
        }
        .enflowBackground()
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Full reload
                Button(action: { Task { await loadData() } }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.yellow)
                }
                .accessibilityLabel("Reload all data and summary")
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedEventDate != nil },
            set: { if !$0 { selectedEventDate = nil } }
        )) {
            if let date = selectedEventDate {
                DayView(date: date, showBackButton: true)
            }
        }
        .task { await loadData() }
    }

    /// Full data reload (chart + summary)
    private func loadData() async {
        await loadChartData()
        await loadEnergyInsight()
        await loadGPTSummary()
    }

    /// Reload only the GPT YAML summary with simplified formatting instructions.
    private func loadGPTSummary() async {
        let prompt = """
Respond only with YAML.
sections:
  - title: ""
    content: ""
events:
  - title: ""
    date: YYYY-MM-DD
Highlight any mentioned event titles using <highlight> tags. No markdown or extra commentary.
"""
        do {
            let raw = try await OpenAIManager.shared.generateInsight(
                prompt: prompt,
                cacheId: "WeeklyYAML.\(period.rawValue)"
            )
            gptSummary = WeeklySummaryFormatter.format(from: raw)
        } catch {
            gptSummary = "error: Unable to load summary"
        }
    }

    /// Generate a brief personalized energy tip between the accuracy bar and weekly summary.
    private func loadEnergyInsight() async {
        guard !summaries.isEmpty else { return }

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let scoreParts = summaries.map { "\(df.string(from: $0.date)): \(Int($0.overallEnergyScore))" }
        let eventParts = calendarEvents.prefix(10).map { "\(df.string(from: $0.startTime)): \($0.eventTitle)" }

        let prompt = """
        Based on these energy scores: \(scoreParts.joined(separator: ", ")) and recent events: \(eventParts.joined(separator: ", ")).
        Respond with one line of up to three short tags separated by commas, then a newline and one personalized sentence on how the user could improve their score. If there is not plentiful data, offer a lesser-known energy or biohacking tip instead, and cite a reputable study if needed.
        """

        do {
            let raw = try await OpenAIManager.shared.generateInsight(
                prompt: prompt,
                cacheId: "EnergyTip.\(period.rawValue)"
            )
            let parts = raw.components(separatedBy: "\n")
            let tagsLine = parts.first ?? ""
            let textLine = parts.dropFirst().joined(separator: " ")
            let tags = tagsLine.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            await MainActor.run {
                insightTags = tags
                insightText = textLine.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } catch {
            await MainActor.run {
                insightTags = []
                insightText = "Energy tip unavailable."
            }
        }
    }

    /// Fetch only chart data.
    private func loadChartData() async {
        // Determine how many days back based on the period
        let days: Int = {
            switch period {
            case .weekly:   return 7
            case .monthly:  return 30
            case .sixWeeks: return 42
            }
        }()

        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -(days - 1), to: cal.startOfDay(for: Date())) ?? Date()
        let healthList = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: days)
        let allEvents = await CalendarDataPipeline.shared.fetchEvents(start: start, end: cal.date(byAdding: .day, value: days, to: start)!)

        var actual: [DayEnergySummary] = []
        var forecast: [DayEnergySummary] = []
        var accTotal = 0.0
        var accCount = 0

        for i in 0..<days {
            guard let day = cal.date(byAdding: .day, value: i, to: start) else { continue }
            let h = healthList.filter { cal.isDate($0.date, inSameDayAs: day) }
            let ev = allEvents.filter { cal.isDate($0.startTime, inSameDayAs: day) }

            let profile = UserProfileStore.load()
            let summary = UnifiedEnergyModel.shared.summary(for: day, healthEvents: h, calendarEvents: ev, profile: profile)
            actual.append(summary)

            var fWave = ForecastCache.shared.forecast(for: day)?.values
            if fWave == nil {
                if let res = EnergyForecastModel().forecast(for: day, health: h, events: ev, profile: profile)?.values {
                    fWave = res
                    ForecastCache.shared.saveForecast(DayEnergyForecast(date: day,
                                                                     values: res,
                                                                     score: res.reduce(0, +) / Double(res.count) * 100,
                                                                     confidenceScore: 0.2,
                                                                     missingMetrics: [],
                                                                     sourceType: .historicalModel))
                }
            }
            if let wave = fWave {
                let score = wave.reduce(0, +) / Double(wave.count) * 100
                forecast.append(DayEnergySummary(
                    date: day,
                    overallEnergyScore: score.rounded(),
                    mentalEnergy: summary.mentalEnergy,
                    physicalEnergy: summary.physicalEnergy,
                    sleepEfficiency: summary.sleepEfficiency,
                    coverageRatio: summary.coverageRatio,
                    confidence: summary.confidence,
                    warning: summary.warning,
                    debugInfo: summary.debugInfo,
                    hourlyWaveform: wave,
                    topBoosters: [],
                    topDrainers: []
                ))

                if day < cal.startOfDay(for: Date()) {
                    let diffs = zip(wave, summary.hourlyWaveform).map { abs($0 - $1) }
                    let acc = 1.0 - diffs.reduce(0, +) / Double(diffs.count)
                    ForecastCache.shared.saveAccuracy(acc, for: day)
                    accTotal += acc
                    accCount += 1
                }
            }
        }

        let accuracyVal = accCount > 0 ? accTotal / Double(accCount) : 0.0

        await MainActor.run {
            summaries = actual
            forecastSummaries = forecast
            accuracy = accuracyVal
            calendarEvents = allEvents
        }

        await MainActor.run { EnergySummaryEngine.shared.markRefreshed() }
    }


    /// Parses a tapped YAML date and navigates to that day.
    private func handleEventTap(in text: String) {
        let regex = try? NSRegularExpression(pattern: "date:\\s*\"?(\\d{4}-\\d{2}-\\d{2})\"?", options: [])
        if let match = regex?.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
           let r = Range(match.range(at: 1), in: text) {
            let d = String(text[r])
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            selectedEventDate = fmt.date(from: d)
        }
    }

    /// Chart showing calculated and forecasted energy.
    private var energyChart: some View {
        Chart {
            shadeMarks
            actualLineMarks
            forecastLineMarks
            endPointMarks
        }
        .chartForegroundStyleScale(seriesColors)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...100)
        .frame(height: 200)
        .padding(.horizontal)
        .overlay(
            VStack {
                Text("High").font(.caption).foregroundColor(.gray)
                Spacer()
                Text("Low").font(.caption).foregroundColor(.gray)
            }
            .padding(.leading, 4), alignment: .leading
        )
        .onAppear { animatePulse = true }
    }

    // MARK: Chart Content Builders ---------------------------------------

    @ChartContentBuilder
    private var shadeMarks: some ChartContent {
        ForEach(shadeSections) { section in
            ForEach(section.points) { p in
                AreaMark(
                    x: .value("Day", p.date),
                    yStart: .value("Low", p.low),
                    yEnd: .value("High", p.high)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(section.color)
            }
        }
    }

    @ChartContentBuilder
    private var actualLineMarks: some ChartContent {
        ForEach(summaries) { item in
            LineMark(
                x: .value("Day", item.date),
                y: .value("Energy", item.overallEnergyScore)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(by: .value("Series", "Calculated"))
            .shadow(color: Color.yellow.opacity(0.6), radius: 4)
        }
    }

    @ChartContentBuilder
    private var forecastLineMarks: some ChartContent {
        ForEach(forecastSummaries) { item in
            LineMark(
                x: .value("Day", item.date),
                y: .value("Energy", item.overallEnergyScore)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(by: .value("Series", "Forecasted"))
            .shadow(color: forecastColor.opacity(0.6), radius: 4)
        }
    }

    @ChartContentBuilder
    private var endPointMarks: some ChartContent {
        if let lastA = summaries.last {
            PointMark(
                x: .value("Day", lastA.date),
                y: .value("Energy", lastA.overallEnergyScore)
            )
            .symbol(.circle)
            .symbolSize(animatePulse ? 96 : 64)
            .foregroundStyle(by: .value("Series", "Calculated"))
            .shadow(radius: 8)
        }
        if let lastF = forecastSummaries.last {
            PointMark(
                x: .value("Day", lastF.date),
                y: .value("Energy", lastF.overallEnergyScore)
            )
            .symbol(.circle)
            .symbolSize(animatePulse ? 96 : 64)
            .foregroundStyle(by: .value("Series", "Forecasted"))
            .shadow(radius: 8)
        }
    }

    // MARK: Derived Data --------------------------------------------------

    private var shadeSections: [ShadeSection] {
        guard summaries.count == forecastSummaries.count else { return [] }
        var sections: [ShadeSection] = []
        var currentColor: Color? = nil
        var currentPoints: [ShadePoint] = []
        for (a, f) in zip(summaries, forecastSummaries) {
            let color: Color = a.overallEnergyScore >= f.overallEnergyScore ? Color.yellow.opacity(0.2) : forecastColor.opacity(0.2)
            let point = ShadePoint(date: a.date,
                                   low: min(a.overallEnergyScore, f.overallEnergyScore),
                                   high: max(a.overallEnergyScore, f.overallEnergyScore))
            if currentColor == nil || color != currentColor {
                if let c = currentColor, !currentPoints.isEmpty {
                    sections.append(ShadeSection(points: currentPoints, color: c))
                    currentPoints.removeAll()
                }
                currentColor = color
            }
            currentPoints.append(point)
        }
        if let c = currentColor, !currentPoints.isEmpty {
            sections.append(ShadeSection(points: currentPoints, color: c))
        }
        return sections
    }

    private struct ShadePoint: Identifiable {
        let id = UUID()
        let date: Date
        let low: Double
        let high: Double
    }

    private struct ShadeSection: Identifiable {
        let id = UUID()
        let points: [ShadePoint]
        let color: Color
    }

}


// MARK: Helpers

struct EnergyInsightsCard: View {
    let tags: [String]
    let text: String
    let forecastColor: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(Color.yellow.opacity(0.2)).frame(width: 48, height: 48)
                    .overlay(Image(systemName: "bolt.fill").font(.title2).foregroundColor(.yellow))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            Text(tag).font(.caption2.bold())
                                .padding(.vertical, 4).padding(.horizontal, 8)
                                .background(Capsule().fill(forecastColor.opacity(0.1)))
                                .foregroundColor(forecastColor)
                        }
                    }
                }
            }
            Text(text).font(.body).foregroundColor(.white)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(radius: 4)

    }
}
