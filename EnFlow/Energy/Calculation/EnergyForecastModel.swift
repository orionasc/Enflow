//  EnergyForecastModel.swift
//  EnFlow
//
//  PIVOT → Energy-only model   (2025-06-17)
//  • Eliminated predictedStress / predictedRecovery usage
//  • Added circadian-weighted, research-based base-energy formula
//  • Hourly waveform now starts flat; event deltas will be layered in a later patch

import Combine
import Foundation
import HealthKit

// MARK: - EnergyForecastModel ---------------------------------------------------
@MainActor
final class EnergyForecastModel: ObservableObject {

  // Published summaries (still produced by EnergySummaryEngine)
  @Published private(set) var dailySummaries: [DayEnergySummary] = []

  private let calendar = Calendar.current
  private let summaryEngine = EnergySummaryEngine.shared

  // Deprecated; use DayEnergyForecast instead
  struct ForecastResult {
    let values: [Double]
    let score: Double
  }
  struct EnergyParts {
    let morning: Double
    let afternoon: Double
    let evening: Double
  }

  // MARK: Daily rebuild
  func rebuildSummaries(health: [HealthEvent], events: [CalendarEvent]) {
    let healthByDay = Dictionary(grouping: health, by: { calendar.startOfDay(for: $0.date) })
    let eventsByDay = Dictionary(grouping: events, by: { calendar.startOfDay(for: $0.startTime) })
    let keys = Set(healthByDay.keys).union(eventsByDay.keys)

    dailySummaries = keys.sorted().map { day in
      summaryEngine.summarize(
        day: day,
        healthEvents: healthByDay[day] ?? [],
        calendarEvents: eventsByDay[day] ?? [],
        profile: nil)
    }
  }

  // MARK: Single-day forecast (24×values + daily composite)
  func forecast(
    for date: Date,
    health: [HealthEvent],
    events: [CalendarEvent],
    profile: UserProfile? = nil
  ) -> DayEnergyForecast? {

    let dayHealth = health.first { calendar.isDate($0.date, inSameDayAs: date) }
    let eligible = dayHealth.map { isEnergyEligible($0) } ?? false

    if let cached = ForecastCache.shared.forecast(for: date) {
      switch cached.sourceType {
      case .historicalModel:
        if eligible { return cached }
      case .defaultHeuristic:
        if !eligible && !cached.values.isEmpty { return cached }
        else { ForecastCache.shared.removeForecast(for: date) }
      }
    }

    let history = health.filter { $0.date <= date }
    print("[EnergyForecastModel] 🔍 history days for \(date): \(history.count)")
    guard let hSample = history.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) ?? history.last else {
      return nil
    }

    guard isEnergyEligible(hSample) else {
      let missing = missingRequiredMetrics(hSample)
      let debugInfo = "missing: \(missing.map { $0.rawValue }.joined(separator: ","))"
      ForecastCache.shared.removeForecast(for: date)
      return DayEnergyForecast(date: date,
                               values: [],
                               score: 0,
                               confidenceScore: 0,
                               missingMetrics: missing,
                               sourceType: .defaultHeuristic,
                               debugInfo: debugInfo)
    }

    guard let base = computeHistoricalBase(from: history) else {
      ForecastCache.shared.removeForecast(for: date)
      return DayEnergyForecast(date: date,
                               values: [],
                               score: 0,
                               confidenceScore: 0,
                               missingMetrics: MetricType.allCases,
                               sourceType: .defaultHeuristic,
                               debugInfo: "no history")
    }

    var adjustedBase = base
    if let p = profile {
      adjustedBase += Double(p.exerciseFrequency - 3) * 0.01
      if !p.mealsRegular { adjustedBase -= 0.03 }
      adjustedBase = min(max(adjustedBase, 0), 1)
    }

    var wave = circadian(for: profile).map { clamp(adjustedBase + $0) }
    for ev in events {
      guard let delta = ev.energyDelta else { continue }
      let hr = calendar.component(.hour, from: ev.startTime)
      if hr >= 0 && hr < 24 {
        apply(delta: delta, at: hr, to: &wave)
      }
    }

    if let p = profile, p.caffeineMgPerDay > 300 {
      var dipHours: [Int] = []
      if p.caffeineMorning     { dipHours.append(11) }
      if p.caffeineAfternoon   { dipHours.append(18) }
      if p.caffeineEvening     { dipHours.append(23) }
      for h in dipHours {
        let idx = h % 24
        wave[idx] = max(0, wave[idx] - 0.1)
      }
    }

    wave = smooth(wave)
    // Apply user profile's bed/wake adjustments
    shapeBedWake(for: date, profile: profile, calendar: calendar, into: &wave)


    let missing = Set(MetricType.allCases).subtracting(hSample.availableMetrics)
    var confidence = 0.2
    if history.count >= 7 { confidence = 0.8 } else if history.count >= 3 { confidence = 0.4 }

    wave = applySleepFloor(to: wave, profile: profile, available: hSample.availableMetrics, confidence: confidence)
    wave = adjustAmplitude(of: wave, base: adjustedBase, confidence: confidence)

    let score = wave.reduce(0, +) / Double(wave.count) * 100.0

    var debugInfo: String? = nil
    if confidence < 0.5 {
      let mList = missing.map { $0.rawValue }.joined(separator: ",")
      debugInfo = "missing: \(mList)"
    }

    let forecast = DayEnergyForecast(
      date: date,
      values: wave,
      score: score,
      confidenceScore: confidence,
      missingMetrics: Array(missing),
      sourceType: .historicalModel,
      debugInfo: debugInfo)
    ForecastCache.shared.saveForecast(forecast)
    return forecast
  }

  // MARK: 3-part (morning / afternoon / evening)
  func threePartEnergy(
    for date: Date,
    health: [HealthEvent],
    events: [CalendarEvent],
    profile: UserProfile? = nil
  ) -> EnergyParts? {

    guard let wave = forecast(for: date, health: health, events: events, profile: profile)?.values else { return nil }
    func avg(_ range: Range<Int>) -> Double {
      let vals = energySlice(wave, range: range)
      return vals.reduce(0, +) / Double(vals.count) * 100.0
    }
    return EnergyParts(
      morning: avg(6..<12),
      afternoon: avg(12..<18),
      evening: avg(18..<24))
  }


  // MARK: Base-energy score (0.0–1.0) -----------------------------------------
  private func computeBaseEnergy(from h: HealthEvent?) -> Double? {
    guard let h, h.hasSamples else { return nil }

    // --- Normalised inputs (0–1) ------------------------------------------
    let sleepEff: Double
    if h.availableMetrics.contains(.sleepEfficiency) {
      sleepEff = norm(h.sleepEfficiency, 60, 100)
    } else if h.availableMetrics.contains(.timeInBed) {
      sleepEff = norm(h.timeInBed, 300, 540) // minutes
    } else {
      sleepEff = 0.5
    }

    let hrvScore = h.availableMetrics.contains(.heartRateVariabilitySDNN) ?
      norm(h.hrv, 20, 120) : 0.5

    let restHRInv: Double
    if h.availableMetrics.contains(.restingHR) {
      restHRInv = 1.0 - norm(h.restingHR, 40, 100)
    } else if h.availableMetrics.contains(.heartRate) {
      restHRInv = 1.0 - norm(h.heartRate, 50, 120)
    } else {
      restHRInv = 0.5
    }

    let deepREM: Double
    if h.availableMetrics.contains(.deepSleep) || h.availableMetrics.contains(.remSleep) {
      deepREM = norm(h.deepSleep + h.remSleep, 60, 300)
    } else {
      deepREM = 0.5
    }

    let actBal = activityScore(steps: h.steps)  // z-score proximity

    // --- Weighted composite (literature-based) ----------------------------
    var e = 0.35 * sleepEff + 0.25 * hrvScore + 0.15 * restHRInv + 0.15 * deepREM + 0.10 * actBal

    return max(0.0, min(1.0, e))
  }

  /// Moving-average base energy across recent history (7–14 days).
  private func computeHistoricalBase(from history: [HealthEvent]) -> Double? {
    let recent = history.suffix(14)
    let valid = recent.compactMap { computeBaseEnergy(from: $0) }
    guard !valid.isEmpty else { return nil }
    let range = valid.suffix(7)
    let avg = range.reduce(0, +) / Double(range.count)
    return max(0.3, avg)
  }

  // MARK: Helpers -------------------------------------------------------------

  /// 5-point weighted smoothing (Gaussian-like) to reduce volatility
  private func smooth(_ values: [Double]) -> [Double] {
    guard values.count >= 5 else { return values }
    var out = values
    for i in 2..<(values.count - 2) {
      let v =   values[i-2] * 1
              + values[i-1] * 2
              + values[i]   * 3
              + values[i+1] * 2
              + values[i+2] * 1
      out[i] = v / 9.0
    }
    return out
  }

  /// Clamp helper to keep values within 0…1
  private func clamp(_ v: Double) -> Double { max(0, min(1, v)) }

  /// Apply an event delta over a 3-hour window instead of a single spike
  private func apply(delta: Double, at hour: Int, to wave: inout [Double]) {
    let idxs = [hour - 1, hour, hour + 1]
    let weights: [Double] = [0.25, 0.5, 0.25]
    for (offset, h) in idxs.enumerated() where h >= 0 && h < wave.count {
      wave[h] = clamp(wave[h] + delta * weights[offset])
    }
  }

  /// Scales deviations from the base when confidence is low
  private func adjustAmplitude(of wave: [Double], base: Double, confidence: Double) -> [Double] {
    guard confidence < 0.5 else { return wave }
    let factor = 0.5 + confidence
    return wave.map { base + ($0 - base) * factor }
  }

  /// Forces a low baseline during typical sleep hours when data is limited
  private func applySleepFloor(to wave: [Double], profile: UserProfile?, available: Set<MetricType>, confidence: Double) -> [Double] {
    guard let p = profile else { return wave }
    let hasTIB = available.contains(.timeInBed)
    let hasEff = available.contains(.sleepEfficiency)
    guard confidence < 0.4 && (!hasTIB || !hasEff) else { return wave }

    var result = wave
    let start = calendar.component(.hour, from: p.typicalSleepTime)
    let end = calendar.component(.hour, from: p.typicalWakeTime)
    var h = start
    repeat {
      if h >= 0 && h < result.count { result[h] = min(result[h], 0.2) }
      h = (h + 1) % 24
    } while h != end
    return result
  }


  private func circadian(for profile: UserProfile?) -> [Double] {
    guard let p = profile else { return circadianBoost }
    let wake = calendar.component(.hour, from: p.typicalWakeTime)
    var shift = wake - 7
    switch p.chronotype {
    case .morning: shift -= 1
    case .evening: shift += 1
    default: break
    }
    let n = circadianBoost.count
    let offset = ((shift % n) + n) % n
    return Array(circadianBoost[offset..<n] + circadianBoost[0..<offset])
  }
}

