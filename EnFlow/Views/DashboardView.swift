//  DashboardView.swift
//  EnFlow
//
//  Rev. 2025-06-17  PATCH-04
//  • Uses EnergySummaryEngine.shared everywhere (singleton).
//  • Correct EnergyParts conversion for GPT context.
//  • Soft haptic on Today / Tomorrow picker.
//  • Triggers ring-pulse via engine.markRefreshed() after refresh.
//

import SwiftUI

struct DashboardView: View {

  // ───────── Layout ────────────────────────────────────────────
  private let pickerTop: CGFloat = 60  // distance from top safe-area to pill
  private let headerPadding: CGFloat = 52  // distance from top safe-area to first header

  // ───────── Engine (for ring-pulse) ───────────────────────────
  @StateObject private var engine = EnergySummaryEngine.shared

  // ───────── State ─────────────────────────────────────────────
  @State private var todaySummary: DayEnergySummary?
  @State private var tomorrowSummary: DayEnergySummary?

  @State private var todayParts = EnergyForecastModel.EnergyParts(
    morning: 0,
    afternoon: 0,
    evening: 0)
  @State private var tomorrowParts = EnergyForecastModel.EnergyParts(
    morning: 0,
    afternoon: 0,
    evening: 0)
  @State private var todayCtx: SuggestedPriorityContext?
  @State private var tomorrowCtx: SuggestedPriorityContext?

  @State private var isLoading = true
  @State private var stepsToday = 0
  @State private var selection = 0  // 0 = today • 1 = tomorrow
  @State private var missingTodayData = false
  @State private var missingTomorrowData = false
  @State private var tomorrowConfidence: Double = 0

  private typealias EnergyParts = EnergyForecastModel.EnergyParts

  // MARK: Root view ----------------------------------------------------------
  var body: some View {
    TabView(selection: $selection) {
      todayPage.tag(0)
      tomorrowPage.tag(1)
    }
    .tabViewStyle(.page(indexDisplayMode: .never))
    .animation(.easeInOut, value: selection)

    // ───────── Segmented pill ─────────
    .overlay(alignment: .topTrailing) {
      Picker("", selection: $selection) {
        Text("Today").tag(0)
        Text("Tomorrow").tag(1)
      }
      .pickerStyle(.segmented)
      .frame(width: 180)
      .padding(.trailing, 16)
      .padding(.top, pickerTop)
    }
    // Soft haptic on tab switch
    .onChange(of: selection) { _ in
      #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      #endif
    }

    // Notch shim
    .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }

    .enflowBackground()
    .navigationBarHidden(true)
    .environmentObject(engine)  // ring-pulse observer
    .task { await loadData() }
  }

  // MARK: TODAY PAGE ----------------------------------------------------------
  private var todayPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 35) {

        header(
          title: greeting,
          subtitle: "Your energy status for today:")
        if missingTodayData {
          Text("No Health Data")
            .font(.caption)
            .foregroundColor(.orange)
        }

        // — Composite ring —
        if let summary = todaySummary {
          VStack(spacing: 4) {
            EnergyRingView(
              score: missingTodayData ? nil : summary.overallEnergyScore,
              explainers: summary.explainers,
              summaryDate: summary.date
            )
            if stepsToday > 1000000 {
              Text("Steps today: \(stepsToday)")
                .font(.caption2)
                .foregroundColor(.gray)
            }

          }
          .frame(maxWidth: .infinity)

        }

        // — 24-hour line graph —
        if let wave = todaySummary?.hourlyWaveform {
          VStack(alignment: .leading, spacing: 8) {
            Text("24-Hour Energy Forecast")
              .font(.headline)
            EnergyLineChartView(values: wave)
          }
        }

        // — Morning / Afternoon / Evening rings —
        ThreePartForecastView(parts: todayParts)

        // — GPT Suggested Priorities —
        if let ctx = todayCtx {
          SuggestedPrioritiesView(context: ctx)
        }

        Spacer(minLength: 40)
      }
      .padding(.top, headerPadding)
      .padding(.horizontal)
    }
  }

  // MARK: TOMORROW PAGE -------------------------------------------------------
  private var tomorrowPage: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {

        header(
          title: "Tomorrow",
          subtitle: "Tomorrow’s Forecasted Energy")
        if missingTomorrowData {
          Text("No Health Data")
            .font(.caption)
            .foregroundColor(.orange)
        }

        // No forecast for future days – show placeholder
        EnergyRingView(
          score: nil,
          dashed: true,
          desaturate: true
        )
        .frame(maxWidth: .infinity)

        // No hourly forecast shown

        if tomorrowConfidence > 0 && tomorrowConfidence < 0.4 {
          Text("⚠️ Forecast based on limited history – add more days of data for accuracy")
            .font(.caption)
            .foregroundColor(.orange)
        }



        Spacer(minLength: 60)
      }
      .padding(.top, headerPadding)
      .padding(.horizontal)
    }
  }

  // MARK: Header helper -------------------------------------------------------
  private func header(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.largeTitle.bold())
      Text(subtitle)
        .font(.title3)
        .foregroundColor(.gray)
    }
  }

  // MARK: Data load -----------------------------------------------------------
  private func loadData() async {
    isLoading = true

    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    let tomorrow = cal.startOfDay(for: Date().addingTimeInterval(86_400))

    // Health + calendar pulls
    let healthList = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 2)
    let steps = await HealthDataPipeline.shared.stepsToday()
    let eventsToday = await CalendarDataPipeline.shared.fetchEvents(for: today)
    let eventsTomorrow = await CalendarDataPipeline.shared.fetchEvents(for: tomorrow)

    // Daily summaries blended with forecast
    let tSummary = UnifiedEnergyModel.shared.summary(
      for: today,
      healthEvents: healthList,
      calendarEvents: eventsToday)
    let tmSummary = UnifiedEnergyModel.shared.summary(
      for: tomorrow,
      healthEvents: healthList,
      calendarEvents: eventsTomorrow)
    let forecastConf =
      EnergyForecastModel().forecast(
        for: tomorrow,
        health: healthList,
        events: eventsTomorrow)?.confidenceScore ?? 0

    let todayHealth = healthList.first { cal.isDate($0.date, inSameDayAs: today) }
    let tomorrowHealth = healthList.first { cal.isDate($0.date, inSameDayAs: tomorrow) }
    let noToday = !(todayHealth?.hasSamples ?? false)
    let noTomorrow = !(tomorrowHealth?.hasSamples ?? false)

    // 3-part slices
    func slices(from wave: [Double]) -> EnergyForecastModel.EnergyParts {
      func avg(_ s: ArraySlice<Double>) -> Double { s.reduce(0, +) / Double(s.count) * 100 }
      return EnergyForecastModel.EnergyParts(
        morning: avg(wave[0..<8]),
        afternoon: avg(wave[8..<16]),
        evening: avg(wave[16..<24])
      )
    }
    let tParts = slices(from: tSummary.hourlyWaveform)
    let tmParts = slices(from: tmSummary.hourlyWaveform)

    // GPT context builder --------------------------------------------------
    func makeContext(
      for summary: DayEnergySummary,
      parts: EnergyForecastModel.EnergyParts,
      health: HealthEvent?,
      events: [CalendarEvent]
    ) -> SuggestedPriorityContext {

      let overallPct = summary.overallEnergyScore / 100  // 0‒1
      let three = EnergyParts(  // normalised 0‒1 struct
        morning: parts.morning / 100,
        afternoon: parts.afternoon / 100,
        evening: parts.evening / 100
      )
      let sleep = (health?.sleepEfficiency ?? 70) / 100
      let hrv = (health?.hrv ?? 60) / 120

      let free = freeBlocks(from: events, for: summary.date)

      return SuggestedPriorityContext(
        overallEnergy: overallPct,
        threePart: three,
        sleepScore: sleep,
        hrvScore: hrv,
        calendarEvents: events,
        nextFreeBlocks: free)
    }

    let tCtx = makeContext(
      for: tSummary,
      parts: tParts,
      health: healthList.first { cal.isDate($0.date, inSameDayAs: today) },
      events: eventsToday)

    let tmCtx = makeContext(
      for: tmSummary,
      parts: tmParts,
      health: healthList.first { cal.isDate($0.date, inSameDayAs: tomorrow) },
      events: eventsTomorrow)

    await MainActor.run {
      todaySummary = tSummary
      tomorrowSummary = nil
      todayParts = tParts
      tomorrowParts = EnergyParts(morning: 0, afternoon: 0, evening: 0)
      todayCtx = tCtx
      tomorrowCtx = nil
      stepsToday = steps
      isLoading = false
      missingTodayData = noToday
      missingTomorrowData = noTomorrow
      tomorrowConfidence = forecastConf
      engine.markRefreshed()  // trigger ring-pulse animation
    }
  }

  /// Returns ≥15-minute gaps in the day’s schedule.
  private func freeBlocks(from events: [CalendarEvent], for day: Date) -> [DateInterval] {
    let cal = Calendar.current
    let startDay = cal.startOfDay(for: day)
    let endDay = cal.date(byAdding: .day, value: 1, to: startDay)!

    let sorted = events.sorted(by: { $0.startTime < $1.startTime })
    var cursor = startDay
    var blocks: [DateInterval] = []

    for ev in sorted {
      if ev.startTime > cursor {
        let gap = DateInterval(start: cursor, end: ev.startTime)
        if gap.duration >= 900 { blocks.append(gap) }  // ≥15 min
      }
      cursor = max(cursor, ev.endTime)
    }
    if cursor < endDay {
      let gap = DateInterval(start: cursor, end: endDay)
      if gap.duration >= 900 { blocks.append(gap) }
    }
    return blocks
  }

  private var greeting: String {
    switch Calendar.current.component(.hour, from: Date()) {
    case 5..<12: "Good morning"
    case 12..<17: "Good afternoon"
    case 17..<22: "Good evening"
    default: "Welcome back"
    }
  }
}

// MARK: Shared background modifier --------------------------------------------
extension View {
  /// Navy-to-charcoal gradient, ignoring safe-area.
  func enflowBackground() -> some View {
    self.background(
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.05, green: 0.08, blue: 0.20),  // deep navy
          Color(red: 0.12, green: 0.12, blue: 0.12),  // charcoal
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .ignoresSafeArea()
  }
}
