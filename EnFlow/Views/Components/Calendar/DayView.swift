//  DayView.swift
//  EnFlow — Updated Day Calendar with optional back button

import SwiftUI

struct DayView: View {
  // ───────── Inputs ─────────────────────────────────────────
  @State private var currentDate: Date
  let showBackButton: Bool

  @Environment(\.dismiss) private var dismiss

  // ───────── State ──────────────────────────────────────────
  @State private var events: [CalendarEvent] = []
  @State private var forecast: [Double] = Array(repeating: 0.5, count: 24)
  @State private var parts: EnergyForecastModel.EnergyParts? = nil
  @State private var overallScore: Double? = nil
  @State private var showHeatMap = false
  @State private var now = Date()
  @State private var forecastMessage: String? = nil
  @State private var forecastWarning = false
  @State private var summary: DayEnergySummary? = nil
  private enum Page: Int { case schedule, overview }
  @State private var page: Page = .schedule

  private let calendar = Calendar.current
  private let rowHeight: CGFloat = 32
  private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
  private var isToday: Bool { calendar.isDateInToday(currentDate) }
  private var isTomorrow: Bool {
    guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) else { return false }
    return calendar.isDate(currentDate, inSameDayAs: tomorrow)
  }

  // — Computed: split all-day events from timed ones —
  private var allDayEvents: [CalendarEvent] { events.filter { $0.isAllDay } }
  private var timedEvents: [CalendarEvent]  { events.filter { !$0.isAllDay } }

  // ───────── Init ───────────────────────────────────────────
  init(date: Date, showBackButton: Bool = false) {
    _currentDate = State(initialValue: date)
    self.showBackButton = showBackButton
  }

  // MARK: ─ Header with optional back button ──────────────────
  private var dayHeader: some View {
    HStack(spacing: 12) {
      if showBackButton {
        Button(action: { dismiss() }) {
          Image(systemName: "chevron.backward")
            .font(.title3.weight(.semibold))
          Text("Back")
            .font(.subheadline.weight(.semibold))
        }
        .padding(.top, 3)  // tweak to lower the back button
      }

      Button(action: { navigateDay(by: -1) }) {
        Image(systemName: "chevron.left")
          .font(.title3.weight(.semibold))
      }

      Text(
        currentDate.formatted(
          .dateTime.weekday(.wide)
            .month(.abbreviated)
            .day()
        )
      )
      .font(.largeTitle.bold())
      .frame(maxWidth: .infinity)

      Button(action: { navigateDay(by: 1) }) {
        Image(systemName: "chevron.right")
          .font(.title3.weight(.semibold))
      }
    }
    .padding(.horizontal)
  }

  // MARK: ─ Page toggle buttons ───────────────────────────────
  private var pageToggleButtons: some View {
    HStack {
      Button("Schedule") { withAnimation { page = .schedule } }
        .font(.subheadline.weight(.bold))
        .foregroundColor(page == .schedule ? .white : .secondary)
      Spacer()
      Button("Energy") { withAnimation { page = .overview } }
        .font(.subheadline.weight(.bold))
        .foregroundColor(page == .overview ? .white : .secondary)
    }
    .padding(.horizontal)
    .padding(.top, 10)
  }

  // MARK: ─ Page 1: Schedule ───────────────────────────────────
  private var schedulePage: some View {
    ScrollView {
      VStack(spacing: 24) {
        HStack(alignment: .center, spacing: 70) {
          EnergyRingView(
            score: overallScore,
            summaryDate: currentDate,
            size: 150,
            warningMessage: forecastMessage
          )
          .saturation(isTomorrow ? 0.7 : 1)
          VStack(alignment: .center, spacing: 12) {
            labeledMiniRing(title: "Morning", value: parts?.morning)
            labeledMiniRing(title: "Afternoon", value: parts?.afternoon)
            labeledMiniRing(title: "Evening", value: parts?.evening)
          }
        }

        if !allDayEvents.isEmpty {
          VStack(alignment: .leading, spacing: 4) {
            ForEach(allDayEvents) { ev in
              Text(ev.eventTitle)
                .font(.caption.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
          }
        }

        timeline
      }
      .padding()
      .padding(.bottom, 100)
    }
  }

  // MARK: ─ Page 2: 24-hour Overview ───────────────────────────
    private var overviewPage: some View {
      ScrollView {
        VStack(spacing: 40) {

          DayEnergyInsightsView(
            forecast: forecast,
            events: events,
            date: currentDate
          )

          ThreePartForecastView(parts: parts, warningMessage: forecastMessage)

          HStack(spacing: 4) {
            Text("Energy Graph")
              .font(.title2.weight(.medium))
            if let msg = forecastMessage, !forecast.isEmpty {
              WarningIconButton(message: msg)
            }
          }

          if forecast.isEmpty {
            Text("Energy forecast unavailable – not enough health data for this day")
              .frame(maxWidth: .infinity, minHeight: 220)
              .foregroundColor(.secondary)
          } else {
            let profile = UserProfileStore.load()
            let range = visibleRange(for: profile, default: 0..<24)
            let slice = energySlice(forecast, range: range)
            let startHour = range.lowerBound % 24
            let baseHighlight = isToday ? calendar.component(.hour, from: now) : nil
            let highlight = (baseHighlight != nil && range.upperBound > 24 && baseHighlight! < startHour)
              ? baseHighlight! + 24
              : baseHighlight

            Group {
              if let summary {
                let warn = summary.warning != nil || summary.confidence < 0.4
                let msg = warn ? forecastMessage : nil
                DailyEnergyForecastView(
                  values: slice,
                  startHour: startHour,
                  highlightHour: highlight,
                  dotted: warn,
                  warningMessage: msg,
                  lowCoverage: summary.coverageRatio < 0.5
                )
                .saturation(isTomorrow ? 0.7 : 1)
              } else {
                DailyEnergyForecastView(
                  values: slice,
                  startHour: startHour,
                  highlightHour: highlight,
                  dotted: isTomorrow || forecastWarning,
                  warningMessage: forecastMessage
                )
                .saturation(isTomorrow ? 0.7 : 1)
              }
            }
            .frame(height: 220)
          }
        }
        .padding()
        .padding(.bottom, 30)
      }
    }

  // MARK: ─ Timeline with multi-hour blocks ────────────────────
  private var timeline: some View {
    Group {
      if forecast.count == 24 {
        VStack(spacing: 1) {
          ForEach(0..<24, id: \.self) { hr in
            let isForecast = isToday && hr >= calendar.component(.hour, from: now)
            timelineRow(for: hr, showEnergy: showHeatMap, forecasted: isForecast)
          }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(hourMarkers, alignment: .topLeading)
        .overlay(timeIndicator, alignment: .topLeading)
        .overlay(eventsLayer, alignment: .topLeading)
      } else {
        Text("Energy forecast unavailable – not enough health data for this day")
          .font(.headline)
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, minHeight: 100)
          .background(Color.white.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
  }

  @ViewBuilder
  private func timelineRow(for hour: Int, showEnergy: Bool, forecasted: Bool) -> some View {
    let label = hourLabel(hour)
    let energy = forecast.indices.contains(hour) ? forecast[hour] : 0
    let nextEnergy = forecast.indices.contains(hour + 1) ? forecast[hour + 1] : energy
    let fade = fadeFactor(for: hour)
    let baseColor = ColorPalette.color(for: energy * 100)
    let nextColor = ColorPalette.color(for: nextEnergy * 100)
    HStack(spacing: 0) {
      if showEnergy {
        Capsule()
          .fill(
            LinearGradient(
              gradient: Gradient(stops: [
                .init(color: baseColor.opacity(fade), location: 0),
                .init(color: nextColor.opacity(fade), location: 1)
              ]),
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 6, height: rowHeight)
          .padding(.trailing, 4)
          .overlay(
            DotPatternOverlay(color: baseColor)
              .clipShape(Capsule())
              .opacity(forecasted ? 1 : 0)
              .animation(.easeInOut(duration: 0.3), value: forecasted)
          )
      } else {
        Capsule().fill(Color.clear)
          .frame(width: 6, height: rowHeight)
          .padding(.trailing, 4)
      }

      ZStack(alignment: .leading) {
        if showEnergy {
          LinearGradient(
            gradient: Gradient(stops: [
              .init(color: baseColor.opacity(0.12 * fade), location: 0),
              .init(color: nextColor.opacity(0.12 * fade), location: 1)
            ]),
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: rowHeight)
        } else {
          Color.clear.frame(height: rowHeight)
        }
        HStack(spacing: 6) {
          Text(label)
            .font(.caption2)
            .frame(width: 46, alignment: .trailing)
            .foregroundColor(.secondary)
          ZStack(alignment: .topLeading) {
          if showEnergy {
            LinearGradient(
              gradient: Gradient(stops: [
                .init(color: baseColor.opacity(0.22 * fade), location: 0),
                .init(color: nextColor.opacity(0.22 * fade), location: 1)
              ]),
              startPoint: .top,
              endPoint: .bottom
            )
          }
          if showEnergy {
            DotPatternOverlay(color: baseColor)
              .opacity(forecasted ? 1 : 0)
              .animation(.easeInOut(duration: 0.3), value: forecasted)
          }
        }
        .frame(maxHeight: .infinity)
      }

      .frame(height: rowHeight)
    }
  }

  }

  private func eventHeight(from ev: CalendarEvent) -> CGFloat {
    let duration = ev.endTime.timeIntervalSince(ev.startTime) / 3600
    let gaps = floor(duration)
    let height = rowHeight * CGFloat(duration) + CGFloat(gaps)
    return max(rowHeight, height)
  }

  private func fadeFactor(for hour: Int) -> Double {
    guard isToday else { return 1 }
    let fadeStart = 19
    if hour < fadeStart { return 1 }
    let factor = 1 - Double(hour - fadeStart) / 5.0
    return max(0, factor)
  }

  private func energy(at date: Date) -> Double? {
    let hr = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    guard forecast.indices.contains(hr) else { return nil }
    let base = forecast[hr]
    let next = forecast.indices.contains(hr + 1) ? forecast[hr + 1] : base
    return base + (next - base) * Double(minute) / 60.0
  }

  private func isBoost(event ev: CalendarEvent) -> Bool {
    guard let before = energy(at: ev.startTime.addingTimeInterval(-1800)),
          let after = energy(at: ev.endTime.addingTimeInterval(1800)) else {
      return false
    }
    let change = (after - before) * 100
    return change >= 5
  }

  @ViewBuilder
  private var timeIndicator: some View {
    if isToday {
      let hr = calendar.component(.hour, from: now)
      let min = calendar.component(.minute, from: now)
      let offset = (rowHeight + 1) * CGFloat(hr) + rowHeight * CGFloat(min) / 60
      Rectangle()
        .fill(Color.orange)
        .frame(height: 2)
        .offset(x: 0, y: offset)
    }
  }

  private var hourMarkers: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      let spacing = rowHeight + 1
      Canvas { ctx, size in
        for hour in 0...24 {
          let y = CGFloat(hour) * spacing
          var path = Path()
          path.move(to: CGPoint(x: 0, y: y))
          path.addLine(to: CGPoint(x: width, y: y))
          ctx.stroke(path, with: .color(Color.white.opacity(0.1)), lineWidth: 0.5)
        }
      }
    }
  }

  private var eventsLayer: some View {
    GeometryReader { proxy in
      let xOffset: CGFloat = 6 + 4 + 46 + 6
      ForEach(timedEvents) { ev in
        let startHr = calendar.component(.hour, from: ev.startTime)
        let startMin = calendar.component(.minute, from: ev.startTime)
        let offsetY = (rowHeight + 1) * CGFloat(startHr) + rowHeight * CGFloat(startMin) / 60
        let width = proxy.size.width - xOffset
        RoundedRectangle(cornerRadius: 6)
          .fill(.ultraThinMaterial)
          .frame(width: width, height: eventHeight(from: ev))
          .overlay(
            Text(ev.eventTitle)
              .font(.caption2.bold())
              .padding(4)
              .multilineTextAlignment(.leading)
              .frame(maxWidth: .infinity, alignment: .leading),
            alignment: .topLeading
          )
          .overlay(
            Group {
              if isBoost(event: ev) {
                Image(systemName: "bolt.arrow.up.circle.fill")
                  .foregroundColor(.yellow)
                  .brightness(0.3)
                  .saturation(1.8)
                  .shadow(color: Color.yellow.opacity(0.8), radius: 3)
                  .padding(4)
              }
            },
            alignment: .topTrailing
          )
          .offset(x: xOffset, y: offsetY)
          .zIndex(1)
      }
    }
  }

  @ViewBuilder
  private func labeledMiniRing(title: String, value: Double?) -> some View {
    VStack(spacing: 4) {
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.10), lineWidth: 4)
          .frame(width: 32, height: 32)
        if let v = value {
          Circle()
            .trim(from: 0, to: CGFloat(v / 100))
            .stroke(
              ColorPalette.gradient(for: v),
              style: StrokeStyle(lineWidth: 4, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
            .frame(width: 32, height: 32)
          Text("\(Int(v))")
            .font(Font.system(.caption2, design: .rounded).weight(.bold))
            .foregroundColor(.white)
            .shadow(color: ColorPalette.color(for: v).opacity(0.8), radius: 2)
        } else {
          Text("--")
            .font(Font.system(.caption2, design: .rounded).weight(.bold))
            .foregroundColor(.white.opacity(0.6))
            .shadow(color: .white.opacity(0.3), radius: 1.5)
        }
      }
      Text(title)
        .font(.caption2)
        .lineLimit(1)
        .foregroundColor(.white.opacity(0.7))
    }
    .frame(width: 60)
  }

  // MARK: ─ Day-swipe gesture ─────────────────────────────────
  private var daySwipe: some Gesture {
    DragGesture(minimumDistance: 20)
      .onEnded { value in
        if value.translation.width > 50 {
          navigateDay(by: -1)
        } else if value.translation.width < -50 {
          navigateDay(by: 1)
        }
      }
  }

  private func navigateDay(by offset: Int) {
    if let newDate = calendar.date(byAdding: .day, value: offset, to: currentDate) {
      currentDate = newDate
      Task { await load() }
    }
  }


  private func hourLabel(_ hr: Int) -> String {
    var comps = DateComponents()
    comps.hour = hr
    return calendar.date(from: comps)?
      .formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
      ?? "\(hr)h"
  }

  // MARK: ─ Data loader ───────────────────────────────────────
  private func load() async {
    let startOfToday = calendar.startOfDay(for: Date())
    let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
    let diff = calendar.dateComponents([.day], from: currentDate, to: startOfToday).day ?? 0
    let daysBack = max(7, diff + 1)
    let healthList = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: daysBack)
    let dayEvents = await CalendarDataPipeline.shared.fetchEvents(for: currentDate)
    let profile = UserProfileStore.load()

    let summary = SummaryProvider.summary(
      for: currentDate,
      healthEvents: healthList,
      calendarEvents: dayEvents,
      profile: profile
    )

    self.summary = summary
    forecast = summary.hourlyWaveform
    var message: String? = nil
    if summary.warning == "Insufficient health data" {
      message = "Today’s forecast may be incomplete due to missing health data."
    } else if summary.confidence < 0.4 {
      message = "Limited or no data available."
    }
    forecastMessage = message
    forecastWarning = message != nil

    if summary.warning == "Insufficient health data" {
      forecast = []
    }

    showHeatMap = (currentDate <= startOfToday ||
                   calendar.isDate(currentDate, inSameDayAs: startOfTomorrow)) &&
                 summary.warning != "Insufficient health data"
    if showHeatMap {
      overallScore = summary.overallEnergyScore
    } else {
      overallScore = nil
    }

    func avg(_ slice: ArraySlice<Double>) -> Double { slice.reduce(0, +) / Double(slice.count) * 100 }
    if showHeatMap {
      parts = EnergyForecastModel.EnergyParts(
        morning: avg(forecast[0..<8]),
        afternoon: avg(forecast[8..<16]),
        evening: avg(forecast[16..<24])
      )
    } else {
      parts = nil
    }

    events = dayEvents
  }

  var body: some View {
    VStack(spacing: 16) {
      dayHeader

      ZStack {
        RoundedRectangle(cornerRadius: 16)
          .fill(.ultraThinMaterial)
          .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)

        VStack(spacing: 12) {
          pageToggleButtons
          Divider()
            .background(Color.white.opacity(0.2))
            .padding(.horizontal, 16)
          if page == .schedule {
            schedulePage
          } else {
            overviewPage
          }
        }
      }
      .padding(.horizontal)
      .gesture(daySwipe)

      Spacer()
    }
    .navigationBarBackButtonHidden(true)
    .onAppear { Task { await load() } }
    .onReceive(NotificationCenter.default.publisher(for: .didChangeDataMode)) { _ in
      Task { await load() }
    }
    .onReceive(timer) { now = $0 }
    .enflowBackground()
  }
}

#if DEBUG
  struct DayView_Previews: PreviewProvider {
    static var previews: some View {
      NavigationStack {
        DayView(date: Calendar.current.startOfDay(for: Date()), showBackButton: true)
      }
      .previewDevice("iPhone 15 Pro")
    }
  }
#endif
