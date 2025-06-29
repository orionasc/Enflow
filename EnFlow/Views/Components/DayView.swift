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
  private enum Page: Int { case schedule, overview }
  @State private var page: Page = .schedule

  private let calendar = Calendar.current
  private let rowHeight: CGFloat = 32
  private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
  private var isToday: Bool { calendar.isDateInToday(currentDate) }

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
          EnergyRingView(score: overallScore, summaryDate: currentDate)
            .frame(width: 100, height: 100)
          VStack(alignment: .center, spacing: 12) {
            labeledMiniRing(title: "Morning", value: parts?.morning)
            labeledMiniRing(title: "Afternoon", value: parts?.afternoon)
            labeledMiniRing(title: "Evening", value: parts?.evening)
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
      VStack(spacing: 85) {

        EnergyRingView(score: overallScore, summaryDate: currentDate)
          .frame(width: 100, height: 100)

        ThreePartForecastView(parts: parts)
        Text("24-Hour Energy Graph")
          .font(.title2.weight(.medium))
        DailyEnergyForecastView(values: forecast, startHour: 0)
          .frame(height: 220)
      }
      .padding()
      .padding(.bottom, 30)
      .padding(.top, 80)

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
        .overlay(timeIndicator, alignment: .topLeading)
      } else {
        Text("No Data")
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
    let evs = events.filter {
      calendar.component(.hour, from: $0.startTime) == hour
    }
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
            Group {
              if forecasted { DotPatternOverlay(color: baseColor).clipShape(Capsule()) }
            }
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
          if forecasted && showEnergy {
            DotPatternOverlay(color: baseColor)
          }
          ForEach(evs) { ev in
            let startMinute = calendar.component(.minute, from: ev.startTime)
            let minuteOffset = rowHeight * CGFloat(startMinute) / 60
            RoundedRectangle(cornerRadius: 6)
              .fill(.ultraThinMaterial)
              .frame(height: eventHeight(from: ev))
              .overlay(
                Text(ev.eventTitle)
                  .font(.caption2.bold())
                  .padding(4)
                  .multilineTextAlignment(.leading)
                  .frame(maxWidth: .infinity, alignment: .leading),
                alignment: .topLeading
              )
              .offset(y: minuteOffset)
          }
        }
        .frame(maxHeight: .infinity)
      }
      .frame(height: rowHeight)
    }
  }

  private func eventHeight(from ev: CalendarEvent) -> CGFloat {
    let hours = ev.endTime.timeIntervalSince(ev.startTime) / 3600
    return max(rowHeight, rowHeight * CGFloat(hours))
  }

  private func fadeFactor(for hour: Int) -> Double {
    guard isToday else { return 1 }
    let fadeStart = 19
    if hour < fadeStart { return 1 }
    let factor = 1 - Double(hour - fadeStart) / 5.0
    return max(0, factor)
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
            .font(.caption2.bold())
            .foregroundColor(.white)
        } else {
          Text("--")
            .font(.caption2.bold())
            .foregroundColor(.white.opacity(0.6))
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
    let diff = calendar.dateComponents([.day], from: currentDate, to: startOfToday).day ?? 0
    let daysBack = max(7, diff + 1)
    let healthList = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: daysBack)
    let dayEvents = await CalendarDataPipeline.shared.fetchEvents(for: currentDate)
    let profile = UserProfileStore.load()

    let summary = UnifiedEnergyModel.shared.summary(for: currentDate,
                                                    healthEvents: healthList,
                                                    calendarEvents: dayEvents,
                                                    profile: profile)
    forecast = summary.hourlyWaveform
    showHeatMap = summary.coverageRatio >= 0.3 && currentDate <= startOfToday
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
