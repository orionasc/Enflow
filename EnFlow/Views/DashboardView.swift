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
  private let pickerTop: CGFloat = 8  // distance from top safe-area to pill
  private let headerPadding: CGFloat = 52  // distance from top safe-area to first header

  // ───────── Engine (for ring-pulse) ───────────────────────────
  @StateObject private var engine = EnergySummaryEngine.shared

  // ───────── State ─────────────────────────────────────────────
  @State private var todaySummary: DayEnergySummary?
  @State private var tomorrowSummary: DayEnergySummary?

  @State private var todayParts: EnergyParts? = nil
  @State private var tomorrowParts: EnergyParts? = nil
  @State private var todayCtx: SuggestedPriorityContext?
  @State private var tomorrowCtx: SuggestedPriorityContext?

  @State private var isLoading = true
  @State private var stepsToday = 0
  @State private var selection = 0  // 0 = today • 1 = tomorrow
  /// IDs used to recreate inactive pages so they reset scroll position
  @State private var pageIDs: [Int: UUID] = [0: UUID(), 1: UUID()]
  @State private var missingTodayData = false
  @State private var missingTomorrowData = false
  @State private var tomorrowConfidence: Double = 0
  @State private var tomorrowForecastWarning = false
  @State private var tomorrowForecastMessage: String? = nil
  @State private var scrollOffset: CGFloat = 0


  private typealias EnergyParts = EnergyForecastModel.EnergyParts

  /// Opacity for the Today/Tomorrow picker. Dims slightly when scrolled.
  private var pickerOpacity: Double {
    let base = 1 + Double(scrollOffset / 80)
    return min(1, max(0.5, base))
  }

  // MARK: Root view ----------------------------------------------------------
  var body: some View {
    ZStack {
      TabView(selection: $selection) {
        todayPage
          .id(pageIDs[0]!)
          .onAppear { pageIDs[0] = UUID() }
          .tag(0)
        tomorrowPage
          .id(pageIDs[1]!)
          .onAppear { pageIDs[1] = UUID() }
          .tag(1)
      }
      .tabViewStyle(.page(indexDisplayMode: .never))

      if isLoading { ProgressView().progressViewStyle(.circular) }
    }


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
      .opacity(pickerOpacity)
      .animation(.easeInOut(duration: 0.2), value: pickerOpacity)
    }
    // Soft haptic on tab switch
    .onChange(of: selection) { _ in
      #if os(iOS)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      #endif
    }

    // Notch shim
    .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }

    .dashboardBackground(parallaxOffset: scrollOffset)
    .navigationBarTitleDisplayMode(.inline)
    .environmentObject(engine)  // ring-pulse observer
    .task { await loadData() }
    .onReceive(NotificationCenter.default.publisher(for: .didChangeDataMode)) { _ in
      Task { await loadData() }
    }
  }

  // MARK: TODAY PAGE ----------------------------------------------------------
  private var todayPage: some View {
    ScrollView {
      GeometryReader { geo in
        Color.clear
          .preference(key: ScrollOffsetKey.self,
                      value: geo.frame(in: .named("scroll")).minY)
      }
      .frame(height: 0)
      VStack(alignment: .leading, spacing: 35) {

        header(
          title: greeting,
          subtitle: "Your energy status for today:")
        if missingTodayData {
          Text("Not Enough Health Data")
            .font(.caption)
            .foregroundColor(.orange)
        }

        // — Composite ring —
        if let summary = todaySummary {
          VStack(spacing: 4) {
              EnergyRingView(
                score: missingTodayData ? nil : summary.overallEnergyScore,
                animateFromZero: true,
                shimmer: true,
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

        // — Daily line graph —
          if let wave = todaySummary?.hourlyWaveform, !missingTodayData {
            let profile = UserProfileStore.load()
            let range = visibleRange(for: profile, default: 7..<19)
            let slice = energySlice(wave, range: range)
            let startHour = range.lowerBound % 24

            // Move mutation logic out of ViewBuilder context
            let currentHour = Calendar.current.component(.hour, from: Date())
            let highlight = (range.upperBound > 24 && currentHour < startHour)
              ? currentHour + 24
              : currentHour

            VStack(alignment: .leading, spacing: 8) {
              Text("Daily Energy Forecast")
                .font(.headline)
              DailyEnergyForecastView(
                values: slice,
                startHour: startHour,
                highlightHour: highlight
              )
            }
          }



        // — Morning / Afternoon / Evening rings —
        ThreePartForecastView(parts: todayParts)

        // — GPT Actions —
        ActionsView()

        DailyFeedbackCard()

        Spacer(minLength: 40)
      }
      .padding(.top, headerPadding)
      .padding(.horizontal)
    }
    .coordinateSpace(name: "scroll")
    .onPreferenceChange(ScrollOffsetKey.self) { value in
      scrollOffset = value
    }
    .onAppear { scrollOffset = 0 }
    .scrollIndicators(.hidden)
    .scrollIndicators(.hidden)
  }

  // MARK: TOMORROW PAGE -------------------------------------------------------
  private var tomorrowPage: some View {
    ScrollView {
      GeometryReader { geo in
        Color.clear
          .preference(key: ScrollOffsetKey.self,
                      value: geo.frame(in: .named("scroll")).minY)
      }
      .frame(height: 0)
      VStack(alignment: .leading, spacing: 28) {

        header(
          title: "Tomorrow",
          subtitle: "Tomorrow’s Forecasted Energy")
        if missingTomorrowData {
          Text("Not Enough Health Data")
            .font(.caption)
            .foregroundColor(.orange)
        }

        // Forecast (dashed / desaturated)
        EnergyRingView(
          score: missingTomorrowData ? nil : tomorrowSummary?.overallEnergyScore,
          dashed: true,
          desaturate: true,
          warningMessage: tomorrowForecastMessage
        )
        .frame(maxWidth: .infinity)

        if let wave = tomorrowSummary?.hourlyWaveform, !missingTomorrowData {
          let profile = UserProfileStore.load()
          let range = visibleRange(for: profile, default: 0..<24)
          let slice = energySlice(wave, range: range)
          let startHour = range.lowerBound % 24
          VStack(alignment: .leading, spacing: 8) {
            Text("Tomorrow's Energy Forecast")
              .font(.headline)
              .saturation(0.7)
            DailyEnergyForecastView(values: slice,
                                    startHour: startHour,
                                    warningMessage: tomorrowForecastMessage)
              .saturation(0.7)
        }
        }



        ThreePartForecastView(
          parts: tomorrowParts,
          dashed: true,
          desaturate: true,
          warningMessage: tomorrowForecastMessage)

        ActionsView()

        Spacer(minLength: 60)
      }
      .padding(.top, headerPadding)
      .padding(.horizontal)
    }
    .coordinateSpace(name: "scroll")
    .onPreferenceChange(ScrollOffsetKey.self) { value in
      scrollOffset = value
    }
    .onAppear { scrollOffset = 0 }
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
    let healthList = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 14)
    let steps = await HealthDataPipeline.shared.stepsToday()
    let eventsToday = await CalendarDataPipeline.shared.fetchEvents(for: today)
    let eventsTomorrow = await CalendarDataPipeline.shared.fetchEvents(for: tomorrow)

    let profile = UserProfileStore.load()

    // Daily summaries blended with forecast
    let tSummary = SummaryProvider.summary(
      for: today,
      healthEvents: healthList,
      calendarEvents: eventsToday,
      profile: profile)
    let tmSummary = SummaryProvider.summary(
      for: tomorrow,
      healthEvents: healthList,
      calendarEvents: eventsTomorrow,
      profile: profile)
    let fc = EnergyForecastModel().forecast(
        for: tomorrow,
        health: healthList,
        events: eventsTomorrow,
        profile: profile)
    let forecastConf = fc?.confidenceScore ?? 0
    let forecastMsg: String? = {
      guard let f = fc else { return nil }
      if let dbg = f.debugInfo { return "Energy forecast used limited data: \(dbg)." }
      if f.sourceType == .defaultHeuristic {
        return "Today’s forecast is based on fallback logic due to missing health data."
      }
      if f.confidenceScore < 0.4 {
        return "Limited metrics were available. This forecast may be less accurate."
      }
      return nil
    }()
    let forecastWarn = forecastMsg != nil

    let noToday = tSummary.warning == "Insufficient health data"
    let noTomorrow = tmSummary.warning == "Insufficient health data"

    // 3-part slices
    func slices(from wave: [Double]) -> EnergyForecastModel.EnergyParts {
      func avg(_ range: Range<Int>) -> Double {
        let vals = energySlice(wave, range: range)
        return vals.reduce(0, +) / Double(vals.count) * 100
      }
      return EnergyForecastModel.EnergyParts(
        morning: avg(6..<12),
        afternoon: avg(12..<18),
        evening: avg(18..<24)
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
      tomorrowSummary = tmSummary
      todayParts = noToday ? nil : tParts
      tomorrowParts = noTomorrow ? nil : tmParts
      todayCtx = tCtx
      tomorrowCtx = tmCtx
      stepsToday = steps
      isLoading = false
      missingTodayData = noToday
      missingTomorrowData = noTomorrow
      tomorrowConfidence = forecastConf
      tomorrowForecastWarning = forecastWarn
      tomorrowForecastMessage = forecastMsg
      engine.markRefreshed()  // trigger ring-pulse animation
    }
  }


  /// Returns ≥15-minute gaps in the day’s schedule.
  private func freeBlocks(from events: [CalendarEvent], for day: Date) -> [DateInterval] {
    let cal = Calendar.current
    let startDay = cal.startOfDay(for: day)
    guard let endDay = cal.date(byAdding: .day, value: 1, to: startDay) else {
      // If we can't compute the end of the day, there can be no free blocks.
      return []
    }

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

// MARK: Scroll offset preference ---------------------------------------------
private struct ScrollOffsetKey: PreferenceKey {
  static var defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
}

// MARK: Shared background modifier --------------------------------------------
extension View {
  /// Navy-to-charcoal gradient, ignoring safe-area.
  func enflowBackground() -> some View {
    background {
      LinearGradient(
        gradient: Gradient(colors: [
          Color(red: 0.05, green: 0.08, blue: 0.20),  // deep navy
          Color(red: 0.12, green: 0.12, blue: 0.12),  // charcoal
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()
    }
  }

  /// Dashboard gradient with subtle center darkening to emphasise the ring.
  /// Optional parallax offset lets the background track scroll motion.
  func dashboardBackground(parallaxOffset: CGFloat = 0) -> some View {
    background {
      ZStack {
        LinearGradient(
          gradient: Gradient(colors: [
            Color(red: 0.05, green: 0.08, blue: 0.20),  // deep navy
            Color(red: 0.12, green: 0.12, blue: 0.12),  // charcoal
          ]),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        RadialGradient(
          gradient: Gradient(colors: [
            Color.black.opacity(0.25),
            Color.clear
          ]),
          center: .center,
          startRadius: 0,
          endRadius: 300
        )
        .blendMode(.multiply)
      }
      .offset(y: parallaxOffset * 0.25)
      .ignoresSafeArea()
    }
  }
}
