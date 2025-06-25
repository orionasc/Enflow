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
  @State private var parts = EnergyForecastModel.EnergyParts(morning: 0, afternoon: 0, evening: 0)
  @State private var overallScore: Double? = nil
  @State private var page = 0  // 0 = schedule, 1 = overview

  private let calendar = Calendar.current

  // ───────── Init ───────────────────────────────────────────
  init(date: Date, showBackButton: Bool = false) {
    _currentDate = State(initialValue: date)
    self.showBackButton = showBackButton
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
          if page == 0 {
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
    .enflowBackground()
    .navigationBarBackButtonHidden(true)
    .onAppear { Task { await load() } }
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
      Button("Schedule") { withAnimation { page = 0 } }
        .font(.subheadline.weight(.bold))
        .foregroundColor(page == 0 ? .white : .secondary)
      Spacer()
      Button("Energy") { withAnimation { page = 1 } }
        .font(.subheadline.weight(.bold))
        .foregroundColor(page == 1 ? .white : .secondary)
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
            labeledMiniRing(title: "Morning", value: parts.morning)
            labeledMiniRing(title: "Afternoon", value: parts.afternoon)
            labeledMiniRing(title: "Evening", value: parts.evening)
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
        ZStack(alignment: .bottomLeading) {

          EnergyLineChartView(values: forecast)
            .frame(height: 220)
          ForEach(significantPeaksAndTroughs(), id: \.0) { hour, value in
            VStack(alignment: .leading, spacing: 4) {
              RoundedRectangle(cornerRadius: 6)
                .fill(.ultraThinMaterial)
                .frame(width: 140)
                .overlay(
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Hour: \(hourLabel(hour))")
                      .font(.caption2.bold())
                    Text("Energy: \(Int(value * 100))")
                      .font(.caption2)
                    if let ev = events.first(where: {
                      calendar.component(.hour, from: $0.startTime) == hour
                    }) {
                      Text(ev.eventTitle)
                        .font(.caption2)
                        .lineLimit(1)
                    }
                  }
                  .padding(6)
                )
            }
            .offset(
              x: CGFloat(hour) * (UIScreen.main.bounds.width - 32) / 24 + 16,
              y: 16
            )
          }
        }
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
            HStack(spacing: 0) {
              Capsule()
                .fill(ColorPalette.color(for: forecast[hr] * 100))
                .frame(width: 6, height: 32)
                .padding(.trailing, 4)
              timelineRow(for: hr)
            }
          }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
  private func timelineRow(for hour: Int) -> some View {
    let label = hourLabel(hour)
    let energy = forecast.indices.contains(hour) ? forecast[hour] : 0
    let bg = ColorPalette.color(for: energy * 100)
    let evs = events.filter {
      calendar.component(.hour, from: $0.startTime) == hour
    }
    ZStack(alignment: .leading) {
      bg.opacity(0.12).frame(height: 32)
      HStack(spacing: 6) {
        Text(label)
          .font(.caption2)
          .frame(width: 46, alignment: .trailing)
          .foregroundColor(.secondary)
        GeometryReader { geo in
          ZStack(alignment: .leading) {
            Rectangle()
              .fill(bg.opacity(0.22))
              .frame(height: 28)
            ForEach(evs) { ev in
              let startMinute = calendar.component(.minute, from: ev.startTime)
              let durationMinutes = ev.endTime.timeIntervalSince(ev.startTime) / 60
              let durationHours = durationMinutes / 60
              let hourWidth = geo.size.width / 24
              let w = geo.size.width * CGFloat(durationHours) / 24
              Text(ev.eventTitle)
                .font(.caption2.bold())
                .padding(.horizontal, 4)
                .lineLimit(1)
                .frame(width: w, alignment: .leading)
                .background(Color.white.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .offset(x: hourWidth * CGFloat(startMinute) / 60)
            }
          }
        }
      }
      .frame(height: 32)
    }
  }

  @ViewBuilder
  private func labeledMiniRing(title: String, value: Double) -> some View {
    VStack(spacing: 4) {
      ZStack {
        Circle()
          .stroke(Color.white.opacity(0.10), lineWidth: 4)
          .frame(width: 32, height: 32)
        Circle()
          .trim(from: 0, to: CGFloat(value / 100))
          .stroke(
            ColorPalette.gradient(for: value),
            style: StrokeStyle(lineWidth: 4, lineCap: .round)
          )
          .rotationEffect(.degrees(-90))
          .frame(width: 32, height: 32)
        Text("\(Int(value))")
          .font(.caption2.bold())
          .foregroundColor(.white)
      }
      Text(title)
        .font(.caption2)
        .foregroundColor(.white.opacity(0.7))
    }
    .frame(width: 32)
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

  // MARK: ─ Peak/trough markers ───────────────────────────────
  private func significantPeaksAndTroughs(
    threshold: Double = 0.2
  ) -> [(Int, Double)] {
    guard forecast.count == 24 else { return [] }
    var result: [(Int, Double)] = []
    for hr in 1..<23 {
      let prev = forecast[hr - 1]
      let curr = forecast[hr]
      let next = forecast[hr + 1]
      let isPeak = curr > prev && curr > next && curr - min(prev, next) > threshold
      let isTrough = curr < prev && curr < next && max(prev, next) - curr > threshold
      if isPeak || isTrough {
        result.append((hr, curr))
      }
    }
    return result
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
    let healthList = await HealthDataPipeline.shared.fetchDailyHealthEvents(daysBack: 7)
    let dayEvents = await CalendarDataPipeline.shared.fetchEvents(for: currentDate)

    let summary = EnergySummaryEngine.shared.summarize(
      day: currentDate,
      healthEvents: healthList,
      calendarEvents: dayEvents)
    forecast = summary.hourlyWaveform
    let today = calendar.startOfDay(for: Date())
    if currentDate > today || summary.coverageRatio < 0.3 {
      overallScore = nil
    } else {
      overallScore = summary.overallEnergyScore
    }

    func avg(_ slice: ArraySlice<Double>) -> Double {
      slice.reduce(0, +) / Double(slice.count) * 100
    }
    parts = EnergyForecastModel.EnergyParts(
      morning: avg(forecast[0..<8]),
      afternoon: avg(forecast[8..<16]),
      evening: avg(forecast[16..<24])
    )

    events = dayEvents
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
