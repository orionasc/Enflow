import SwiftUI
import Charts
import Foundation

struct GPTSection: Codable, Identifiable {
    let id = UUID()
    let title: String
    let content: String
}

struct GPTEvent: Codable, Identifiable {
    let id = UUID()
    let title: String
    let date: String
}

struct GPTSummary: Codable {
    let sections: [GPTSection]
    let events: [GPTEvent]
}

enum TrendsPeriod: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case sixWeeks = "6 Weeks"
    var id: String { rawValue }
}

/// TrendsView shows energy trends and an AI-generated weekly JSON summary with full control over reloads and formatting.
struct TrendsView: View {
    @State var period: TrendsPeriod = .weekly

    @State private var summaries: [DayEnergySummary] = []
    @State private var forecastSummaries: [DayEnergySummary] = []
    @State private var accuracy: Double = 0.0
    @State private var insightTags: [String] = []
    @State private var insightText: String = ""
    @State var gptSummary: String = ""
    @State var parsedGPTSummary: GPTSummary? = nil
    @State var isGPTLoading = false
    @State private var calendarEvents: [CalendarEvent] = []
    @State private var selectedEventDate: Date? = nil
    @State private var animatePulse = false
    @State private var showInfo = false
    private let infoText = """
    The Trends tab helps you understand how well EnFlow predicts your energy—and how your energy shifts over time. You’ll see two lines: your actual energy (based on real data) and what Sol forecasted for you ahead of time.

    The closer the lines match, the smarter Sol is getting. That accuracy bar? It shows how reliable your energy forecasts have been lately.

    Below that, you’ll find quick insights into emerging patterns and a weekly GPT-generated reflection that highlights recent highs, dips, and behavior connections—like if evening workouts drain you more than they help.

    Come here when you want to zoom out and ask: “Is my energy getting more predictable?” or “What’s the story behind my recent ups and downs?”
    """
    // Use a vivid blue so the forecast line is clearly distinguished
    private let forecastColor = Color.blue
    /// Fixed colour scale so Charts doesn't override our explicit styles
    private let seriesColors: KeyValuePairs<String, Color> = [
        "Calculated": .yellow,
        "Forecasted": .blue
    ]


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
                .onChange(of: period) { _ in
                    Task { await loadData() }
                }
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
                gptSummarySection
                    .padding(.bottom, 30)
            }
        }
        .enflowBackground()
        .navigationTitle("Trends")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button(action: { Task { await loadData() } }) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.yellow)
                    }
                    .accessibilityLabel("Reload all data and summary")

                    Button(action: { showInfo = true }) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.yellow)
                    }
                    .accessibilityLabel("About Trends")
                }
            }
        }
        .sheet(isPresented: $showInfo) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("About Trends")
                        .font(.title.bold())
                        .padding(.bottom, 8)
                    Text(infoText)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .presentationDetents([.fraction(0.5), .large])
            .presentationCornerRadius(20)
            .presentationDragIndicator(.visible)
            .enflowBackground()
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
        .onReceive(NotificationCenter.default.publisher(for: .didChangeDataMode)) { _ in
            Task { await loadData() }
        }
    }

    /// Full data reload (chart + summary)
    private func loadData() async {
        await loadChartData()
        await loadEnergyInsight()
        await loadGPTSummary()
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
        print("[Trends] mode: \(DataModeManager.shared.currentDataMode)")
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
            let summary = SummaryProvider.summary(for: day, healthEvents: h, calendarEvents: ev, profile: profile)
            if summary.warning == "Insufficient health data" {
                continue
            }
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
                                                                        sourceType: .historicalModel, debugInfo: "..."))
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


    /// Parses a tapped JSON date and navigates to that day.
    private func handleEventTap(in json: String) {
        let regex = try? NSRegularExpression(pattern: "\\\"date\\\": \\\"(\\d{4}-\\d{2}-\\d{2})\\\"", options: [])
        if let match = regex?.firstMatch(in: json, options: [], range: NSRange(json.startIndex..., in: json)),
           let r = Range(match.range(at: 1), in: json) {
            let d = String(json[r])
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            selectedEventDate = fmt.date(from: d)
        }
    }

    /// Horizontal swipe gesture to move between weekly, monthly and six-week views.
    private var periodSwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                if value.translation.width > 50 {
                    changePeriod(by: -1)
                } else if value.translation.width < -50 {
                    changePeriod(by: 1)
                }
            }
    }

    private func changePeriod(by delta: Int) {
        if let idx = TrendsPeriod.allCases.firstIndex(of: period) {
            let newIdx = idx + delta
            if TrendsPeriod.allCases.indices.contains(newIdx) {
                period = TrendsPeriod.allCases[newIdx]
            }
        }
    }
    @AxisContentBuilder
    private var xAxisMarks: some AxisContent {
        switch period {
       case .weekly:
            AxisMarks(values: .stride(by: .day)) { value in
                if let date = value.as(Date.self) {
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
        case .monthly, .sixWeeks:
            AxisMarks(values: .stride(by: .weekOfYear)) { value in
                if let date = value.as(Date.self) {
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
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
        .chartLegend(.hidden)
        .chartXAxis {
            xAxisMarks
        }
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
        .contentShape(Rectangle())
        .gesture(periodSwipe)
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
        guard let firstA = summaries.first, let firstF = forecastSummaries.first else { return [] }

        var sections: [ShadeSection] = []

        func shadeColor(for diff: Double) -> Color {
            diff >= 0 ? Color.yellow.opacity(0.2) : forecastColor.opacity(0.2)
        }

        var currentDiff = firstA.overallEnergyScore - firstF.overallEnergyScore
        var currentColor = shadeColor(for: currentDiff)
        var currentPoints: [ShadePoint] = [
            ShadePoint(date: firstA.date,
                       low: min(firstA.overallEnergyScore, firstF.overallEnergyScore),
                       high: max(firstA.overallEnergyScore, firstF.overallEnergyScore))
        ]

        for i in 0..<(summaries.count - 1) {
            let a1 = summaries[i]
            let f1 = forecastSummaries[i]
            let a2 = summaries[i + 1]
            let f2 = forecastSummaries[i + 1]

            let diff1 = a1.overallEnergyScore - f1.overallEnergyScore
            let diff2 = a2.overallEnergyScore - f2.overallEnergyScore

            // Linear interpolation for possible intersection
            if diff1 * diff2 < 0 {
                let t = (f1.overallEnergyScore - a1.overallEnergyScore) /
                        ((a2.overallEnergyScore - a1.overallEnergyScore) - (f2.overallEnergyScore - f1.overallEnergyScore))
                let time1 = a1.date.timeIntervalSince1970
                let time2 = a2.date.timeIntervalSince1970
                let crossTime = time1 + t * (time2 - time1)
                let crossValue = a1.overallEnergyScore + t * (a2.overallEnergyScore - a1.overallEnergyScore)
                let crossDate = Date(timeIntervalSince1970: crossTime)
                let crossPoint = ShadePoint(date: crossDate, low: crossValue, high: crossValue)
                currentPoints.append(crossPoint)
                sections.append(ShadeSection(points: currentPoints, color: currentColor))
                currentDiff = diff2
                currentColor = shadeColor(for: currentDiff)
                currentPoints = [crossPoint]
            }

            let nextPoint = ShadePoint(date: a2.date,
                                       low: min(a2.overallEnergyScore, f2.overallEnergyScore),
                                       high: max(a2.overallEnergyScore, f2.overallEnergyScore))

            if (diff1 >= 0 && diff2 < 0) || (diff1 < 0 && diff2 >= 0) {
                // color already changed when crossing was handled above
                currentPoints.append(nextPoint)
            } else {
                // continue same colour segment
                currentPoints.append(nextPoint)
            }
        }

        if !currentPoints.isEmpty {
            sections.append(ShadeSection(points: currentPoints, color: currentColor))
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
