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

    if let cached = ForecastCache.shared.forecast(for: date) {
      return cached
    }

    let history = health.filter { $0.date <= date }
    guard let hSample = history.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) ?? history.last else {
      return nil
    }

    guard let base = computeHistoricalBase(from: history) else { return nil }

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

    let required: Set<MetricType> = [.stepCount, .restingHR, .activeEnergyBurned]
    let missing = required.subtracting(hSample.availableMetrics)
    var confidence = 0.2
    if history.count >= 7 { confidence = 0.8 } else if history.count >= 3 { confidence = 0.4 }

    wave = applySleepFloor(to: wave, profile: profile, missing: missing, confidence: confidence)
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
    func avg(_ s: ArraySlice<Double>) -> Double { s.reduce(0, +) / Double(s.count) * 100.0 }
    return EnergyParts(
      morning: avg(wave[6..<12]),
      afternoon: avg(wave[12..<18]),
      evening: avg(wave[18..<24]))
  }


  // MARK: Base-energy score (0.0–1.0) -----------------------------------------
  private func computeBaseEnergy(from h: HealthEvent?) -> Double? {
    guard let h, h.hasSamples else { return nil }

    // --- Normalised inputs (0–1) ------------------------------------------
    let sleepEff = norm(h.sleepEfficiency, 60, 100)  // %
    let hrvScore = norm(h.hrv, 20, 120)  // ms
    let restHRInv = 1.0 - norm(h.restingHR, 40, 100)  // bpm (lower is better)
    let deepREM = norm(h.deepSleep + h.remSleep, 60, 300)  // minutes
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
    return avg
  }

  // MARK: Helpers -------------------------------------------------------------
  /// Simple min–max normalisation
  private func norm(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
    guard hi > lo else { return 0.5 }
    return max(0.0, min(1.0, (v - lo) / (hi - lo)))
  }

  /// Activity score peaks when steps within ±1 SD of personal mean (placeholder)
  private func activityScore(steps: Int, mean: Int = 8000, sd: Int = 3000) -> Double {
    let z = Double(steps - mean) / Double(sd)
    return exp(-0.5 * z * z)  // Gaussian bell, 0–1
  }

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
  private func applySleepFloor(to wave: [Double], profile: UserProfile?, missing: Set<MetricType>, confidence: Double) -> [Double] {
    guard let p = profile else { return wave }
    guard confidence < 0.5 || !missing.isEmpty else { return wave }

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

  /// Consensus circadian energy curve (dips ≈ 2 am & 3 pm; peaks ≈ 10 am & 6 pm)
  private let circadianBoost: [Double] = [
    -0.05, -0.05, -0.05, -0.04, -0.02,  // 0-4
    0.02, 0.06, 0.10, 0.12, 0.10,  // 5-9
    0.08, 0.05, 0.03, 0.00, -0.02,  // 10-14
    -0.04, -0.03, 0.00, 0.08, 0.12,  // 15-19
    0.10, 0.05, 0.00, -0.04,  // 20-23
  ]

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
