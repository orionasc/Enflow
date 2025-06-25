import SwiftUI
import Charts
import Foundation

enum TrendsPeriod: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case sixWeeks = "6 Weeks"
    var id: String { rawValue }
}

/// TrendsView shows energy trends and an AI-generated weekly JSON summary with full control over reloads and formatting.
struct TrendsView: View {
    @State private var period: TrendsPeriod = .weekly

    @State private var summaries: [DayEnergySummary] = []
    @State private var forecastSummaries: [DayEnergySummary] = []
    @State private var accuracy: Double = 0.0
    @State private var insightTags: [String] = []
    @State private var insightText: String = ""
    @State private var gptSummary: String = ""
    @State private var selectedEventDate: Date? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Spacer().frame(height: 80)

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
                Chart {
                    ForEach(summaries) { item in
                        LineMark(x: .value("Day", item.date), y: .value("Actual", item.overallEnergyScore))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.yellow)
                    }
                    ForEach(forecastSummaries) { item in
                        LineMark(x: .value("Day", item.date), y: .value("Forecast", item.overallEnergyScore))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue)
                    }
                    if let lastA = summaries.last {
                        PointMark(x: .value("Day", lastA.date), y: .value("Actual", lastA.overallEnergyScore))
                            .symbol(.circle)
                            .symbolSize(80)
                            .foregroundStyle(Color.yellow)
                            .shadow(radius: 8)
                    }
                    if let lastF = forecastSummaries.last {
                        PointMark(x: .value("Day", lastF.date), y: .value("Forecast", lastF.overallEnergyScore))
                            .symbol(.circle)
                            .symbolSize(80)
                            .foregroundStyle(Color.blue)
                            .shadow(radius: 8)
                    }
                }
                .chartYScale(domain: 0...100)
                .frame(height: 200)
                .padding(.horizontal)

                if forecastSummaries.isEmpty {
                    Text("Not enough prediction data to make accurate assessment")
                        .font(.caption)
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
                EnergyInsightsCard(tags: insightTags, text: insightText)
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
                            Text(gptSummary)
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
        await loadGPTSummary()
    }

    /// Reload only the GPT JSON summary with strict formatting instructions.
    private func loadGPTSummary() async {
        let prompt = """
STRICTLY output EXACTLY valid JSON with NO markdown, no code fences, no extra fields. The JSON must have two keys:

"sections": array of objects with keys "title" and "content" (both strings),
"events": array of objects with keys "title" and "date" (ISO 8601 YYYY-MM-DD).

Analyze correlations between the user's calendar events and their energy data. Wrap any referenced event title in <highlight>…</highlight> tags. Output only the JSON object.
"""
        do {
            let raw = try await OpenAIManager.shared.generateInsight(
                prompt: prompt,
                cacheId: "WeeklyJSON.\(period.rawValue)"
            )
            if let data = raw.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data, options: []),
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
               let prettyString = String(data: pretty, encoding: .utf8) {
                gptSummary = prettyString
            } else {
                gptSummary = raw
            }
        } catch {
            gptSummary = "{ \"error\": \"Unable to load summary\" }"
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

            let summary = UnifiedEnergyModel.shared.summary(for: day, healthEvents: h, calendarEvents: ev)
            actual.append(summary)

            var fWave = ForecastCache.shared.forecast(for: day)?.values
            if fWave == nil {
                if let res = EnergyForecastModel().forecast(for: day, health: h, events: ev)?.values {
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
        }

        await MainActor.run { EnergySummaryEngine.shared.markRefreshed() }
    }


    /// Parses a tapped JSON date and navigates to that day.
    private func handleEventTap(in json: String) {
        let regex = try? NSRegularExpression(pattern: "\\\"date\\\": \\\"(\\\\d{4}-\\\\d{2}-\\\\d{2})\\\"", options: [])
        if let match = regex?.firstMatch(in: json, options: [], range: NSRange(json.startIndex..., in: json)),
           let r = Range(match.range(at: 1), in: json) {
            let d = String(json[r])
            let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"
            selectedEventDate = fmt.date(from: d)
        }
    }
}


// MARK: Helpers

struct EnergyInsightsCard: View {
    let tags: [String]
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle().fill(Color.yellow.opacity(0.2)).frame(width: 48, height: 48)
                    .overlay(Image(systemName: "bolt.fill").font(.title2).foregroundColor(.yellow))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \ .self) { tag in
                            Text(tag).font(.caption2.bold())
                                .padding(.vertical, 4).padding(.horizontal, 8)
                                .background(Capsule().fill(Color.blue.opacity(0.1)))
                                .foregroundColor(.blue)
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
