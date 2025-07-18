// HealthDataPipeline.swift
// EnFlow – Apple HealthKit integration only

import Foundation
import HealthKit
import SwiftUI

// MARK: - Pipeline
final class HealthDataPipeline: ObservableObject {
    static let shared = HealthDataPipeline()

    private let store = HKHealthStore()
    private let calendar = Calendar.current
    private var isSimulated: Bool {
        DataModeManager.shared.isSimulated()
    }

    private init() {}

    // MARK: Authorisation
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // Build as an *array*, then cast to Set for the API call.
        let sampleTypes: [HKSampleType] = [
            // Required
                HKObjectType.quantityType(forIdentifier: .stepCount),
                HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
                HKObjectType.quantityType(forIdentifier: .heartRate),
                HKObjectType.categoryType(forIdentifier: .sleepAnalysis),

                // Optional Enhancers
                HKObjectType.quantityType(forIdentifier: .restingHeartRate),
                HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                HKObjectType.quantityType(forIdentifier: .respiratoryRate),
                HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
                HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage),
                HKObjectType.quantityType(forIdentifier: .vo2Max),
                HKObjectType.categoryType(forIdentifier: .menstrualFlow),
                HKObjectType.categoryType(forIdentifier: .mindfulSession),
                HKObjectType.quantityType(forIdentifier: .environmentalAudioExposure)
        ].compactMap { $0 }

        let readTypes = Set(sampleTypes)

        store.requestAuthorization(toShare: nil, read: readTypes) { success, _ in
            DispatchQueue.main.async { completion(success) }
        }
    }

    // MARK: Daily summaries
    /// Returns an array of `HealthEvent` objects (one per day) going `daysBack` into the past.
    @MainActor
    func fetchDailyHealthEvents(daysBack: Int = 7) async -> [HealthEvent] {
        if isSimulated {
            return SimulatedHealthLoader.shared.load(daysBack: daysBack)
        }

        let today = calendar.startOfDay(for: Date())
        let days  = (0..<daysBack).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }

        var out: [HealthEvent] = []
        for day in days {
            let next = calendar.date(byAdding: .day, value: 1, to: day)!

            // --- Quantities ————————————————————
            let (hrvMs, hrvValid) = await averageQuantity(.heartRateVariabilitySDNN,
                                                         unit: HKUnit.secondUnit(with: .milli),
                                                         start: day, end: next)

            let (restHR, restValid) = await averageQuantity(.restingHeartRate,
                                                            unit: HKUnit.count().unitDivided(by: HKUnit.minute()),
                                                            start: day, end: next)

            let (avgHR, hrValid) = await averageQuantity(.heartRate,
                                                        unit: HKUnit.count().unitDivided(by: HKUnit.minute()),
                                                        start: day, end: next)

            let (steps, stepsValid)  = await sumQuantity(.stepCount,
                                                        unit: .count(),
                                                        start: day, end: next)

            let (calories, caloriesValid) = await sumQuantity(.activeEnergyBurned,
                                                             unit: .kilocalorie(),
                                                             start: day, end: next)

            // --- Sleep metrics ————————————————
            let (eff, lat, deep, rem, inBed, sleepValid) = await parseSleepMetrics(start: day, end: next)

            var metrics: Set<MetricType> = []
            if stepsValid       { metrics.insert(.stepCount) }
            if restValid        { metrics.insert(.restingHR) }
            if hrValid          { metrics.insert(.heartRate) }
            if caloriesValid    { metrics.insert(.activeEnergyBurned) }
            if hrvValid         { metrics.insert(.heartRateVariabilitySDNN) }
            if eff > 0 && sleepValid { metrics.insert(.sleepEfficiency) }
            if lat > 0 && sleepValid { metrics.insert(.sleepLatency) }
            if deep > 0 && sleepValid { metrics.insert(.deepSleep) }
            if rem > 0 && sleepValid { metrics.insert(.remSleep) }
            if sleepValid       { metrics.insert(.timeInBed) }

            let hasData = !metrics.isEmpty
            if !hasData {
                print("[HealthDataPipeline] No HealthKit samples for \(day)")
            }

            out.append(
                HealthEvent(
                    date: day,
                    hrv: hrvMs,
                    restingHR: restHR,
                    heartRate: avgHR,
                    sleepEfficiency: eff,
                    sleepLatency: lat,
                    deepSleep: deep,
                    remSleep: rem,
                    timeInBed: inBed,
                    steps: Int(steps),
                    calories: calories,
                    availableMetrics: metrics,
                    hasSamples: hasData
                )
            )
        }
        return out.sorted { $0.date < $1.date }
    }

    // MARK: - HK Query helpers
    private func averageQuantity(_ id: HKQuantityTypeIdentifier,
                                 unit: HKUnit,
                                 start: Date,
                                 end: Date) async -> (Double, Bool) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return (0, false) }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, stats, _ in
                if let qty = stats?.averageQuantity() {
                    cont.resume(returning: (qty.doubleValue(for: unit), true))
                } else {
                    cont.resume(returning: (0, false))
                }
            }
            store.execute(q)
        }
    }

    private func sumQuantity(_ id: HKQuantityTypeIdentifier,
                             unit: HKUnit,
                             start: Date,
                             end: Date) async -> (Double, Bool) {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return (0, false) }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                if let qty = stats?.sumQuantity() {
                    cont.resume(returning: (qty.doubleValue(for: unit), true))
                } else {
                    cont.resume(returning: (0, false))
                }
            }
            store.execute(q)
        }
    }

    private func parseSleepMetrics(start: Date, end: Date) async -> (eff: Double, latency: Double, deep: Double, rem: Double, inBed: Double, valid: Bool) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return (0,0,0,0,0,false) }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType,
                                   predicate: predicate,
                                   limit: HKObjectQueryNoLimit,
                                   sortDescriptors: nil) { _, samples, _ in
                var total = 0.0, asleep = 0.0, latency = 0.0, deep = 0.0, rem = 0.0
                var firstStart: Date?, lastEnd: Date?
                let hasSamples = !(samples ?? []).isEmpty

                for case let s as HKCategorySample in samples ?? [] {
                    let dur = s.endDate.timeIntervalSince(s.startDate)
                    total += dur
                    if firstStart == nil || s.startDate < firstStart! { firstStart = s.startDate }
                    if lastEnd == nil || s.endDate > lastEnd! { lastEnd = s.endDate }
                    switch s.value {
                    case HKCategoryValueSleepAnalysis.asleep.rawValue:
                        asleep += dur
                    case HKCategoryValueSleepAnalysis.asleepREM.rawValue:
                        rem += dur
                    case HKCategoryValueSleepAnalysis.asleepDeep.rawValue:
                        deep += dur
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        latency += dur
                    default: break
                    }
                }
                let efficiency = total > 0 ? asleep / total * 100 : 0
                let inBed = (firstStart != nil && lastEnd != nil) ? lastEnd!.timeIntervalSince(firstStart!) / 60.0 : 0
                cont.resume(returning: (efficiency, latency/60, deep/60, rem/60, inBed, hasSamples))
            }
            store.execute(q)
        }
    }

    // MARK: Quick fetches
    /// Returns today\'s step count as an integer value.
    @MainActor
    func stepsToday() async -> Int {
        if isSimulated {
            return SimulatedHealthLoader.shared.load(daysBack: 1).first?.steps ?? 0
        }

        let start = calendar.startOfDay(for: Date())
        let end   = calendar.date(byAdding: .day, value: 1, to: start)!
        let (count, _) = await sumQuantity(.stepCount,
                                           unit: .count(),
                                           start: start,
                                           end: end)
        return Int(count)
    }

    func clearCache() {
        // No persistent caching implemented; placeholder for future use.
    }
}
