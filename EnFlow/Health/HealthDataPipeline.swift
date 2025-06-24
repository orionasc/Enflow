// HealthDataPipeline.swift
// EnFlow – Apple HealthKit integration only

import Foundation
import HealthKit

// MARK: - Pipeline
final class HealthDataPipeline: ObservableObject {
    static let shared = HealthDataPipeline()

    private let store = HKHealthStore()
    private let calendar = Calendar.current

    private init() {}

    // MARK: Authorisation
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        // Build as an *array*, then cast to Set for the API call.
        let sampleTypes: [HKSampleType] = [
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .appleExerciseTime),
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)
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
        let today = calendar.startOfDay(for: Date())
        let days  = (0..<daysBack).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }

        var out: [HealthEvent] = []
        for day in days {
            let next = calendar.date(byAdding: .day, value: 1, to: day)!

            // --- Quantities ————————————————————
            let hrvMs = await averageQuantity(.heartRateVariabilitySDNN,
                                              unit: HKUnit.secondUnit(with: .milli),
                                              start: day, end: next)

            let restHR = await averageQuantity(.restingHeartRate,
                                               unit: HKUnit.count().unitDivided(by: HKUnit.minute()),
                                               start: day, end: next)

            let steps  = await sumQuantity(.stepCount,
                                           unit: .count(),
                                           start: day, end: next)

            let calories = await sumQuantity(.activeEnergyBurned,
                                             unit: .kilocalorie(),
                                             start: day, end: next)

            // --- Sleep metrics ————————————————
            let (eff, lat, deep, rem) = await parseSleepMetrics(start: day, end: next)

            out.append(
                HealthEvent(
                    date: day,
                    hrv: hrvMs,
                    restingHR: restHR,
                    sleepEfficiency: eff,
                    sleepLatency: lat,
                    deepSleep: deep,
                    remSleep: rem,
                    steps: Int(steps),
                    calories: calories
                )
            )
        }
        return out.sorted { $0.date < $1.date }
    }

    // MARK: - HK Query helpers
    private func averageQuantity(_ id: HKQuantityTypeIdentifier,
                                 unit: HKUnit,
                                 start: Date,
                                 end: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .discreteAverage) { _, stats, _ in
                let val = stats?.averageQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: val)
            }
            store.execute(q)
        }
    }

    private func sumQuantity(_ id: HKQuantityTypeIdentifier,
                             unit: HKUnit,
                             start: Date,
                             end: Date) async -> Double {
        guard let type = HKObjectType.quantityType(forIdentifier: id) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { _, stats, _ in
                let val = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                cont.resume(returning: val)
            }
            store.execute(q)
        }
    }

    private func parseSleepMetrics(start: Date, end: Date) async -> (eff: Double, latency: Double, deep: Double, rem: Double) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return (0,0,0,0) }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)

        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: sleepType,
                                   predicate: predicate,
                                   limit: HKObjectQueryNoLimit,
                                   sortDescriptors: nil) { _, samples, _ in
                var total = 0.0, asleep = 0.0, latency = 0.0, deep = 0.0, rem = 0.0

                for case let s as HKCategorySample in samples ?? [] {
                    let dur = s.endDate.timeIntervalSince(s.startDate)
                    total += dur
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
                cont.resume(returning: (efficiency, latency/60, deep/60, rem/60))
            }
            store.execute(q)
        }
    }
}
