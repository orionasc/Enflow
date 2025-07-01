import Foundation

// MARK: - SimulatedHealthLoader
/// Generates synthetic health data for previews and testing.
final class SimulatedHealthLoader {
    static let shared = SimulatedHealthLoader()
    private init() {}

    /// Returns synthetic health data covering today and `daysBack` history.
    func load(daysBack: Int = 7) -> [HealthEvent] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var rng = SystemRandomNumberGenerator()

        return (0..<daysBack).compactMap { offset -> HealthEvent? in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }

            let steps = Int(clampedNormal(mean: 8000, sd: 1500, minValue: 4000, maxValue: 11000, using: &rng))
            let hrv = clampedNormal(mean: 70, sd: 7, minValue: 55, maxValue: 85, using: &rng)
            let resting = clampedNormal(mean: 63, sd: 3, minValue: 58, maxValue: 70, using: &rng)
            let sleepHours = clampedNormal(mean: 7.5, sd: 0.4, minValue: 6.5, maxValue: 8.5, using: &rng)
            let deepRatio = clampedNormal(mean: 0.2, sd: 0.04, minValue: 0.1, maxValue: 0.3, using: &rng)
            let remRatio = clampedNormal(mean: 0.25, sd: 0.04, minValue: 0.15, maxValue: 0.35, using: &rng)
            let latency = clampedNormal(mean: 15, sd: 5, minValue: 5, maxValue: 40, using: &rng)
            let efficiency = clampedNormal(mean: 85, sd: 5, minValue: 75, maxValue: 95, using: &rng)
            let activeEnergy = clampedNormal(mean: 850, sd: 80, minValue: 700, maxValue: 1000, using: &rng)

            let deep = sleepHours * 60 * deepRatio
            let rem = sleepHours * 60 * remRatio

            let metrics: Set<MetricType> = [
                .stepCount,
                .restingHR,
                .activeEnergyBurned,
                .heartRateVariabilitySDNN,
                .sleepEfficiency,
                .sleepLatency,
                .deepSleep,
                .remSleep
            ]

            return HealthEvent(
                date: day,
                hrv: hrv,
                restingHR: resting,
                sleepEfficiency: efficiency,
                sleepLatency: latency,
                deepSleep: deep,
                remSleep: rem,
                steps: steps,
                calories: activeEnergy,
                availableMetrics: metrics,
                hasSamples: true
            )
        }.sorted { $0.date < $1.date }
    }

    // MARK: Random Helpers
    private func gaussian(using rng: inout SystemRandomNumberGenerator) -> Double {
        let u1 = Double.random(in: 0..<1, using: &rng)
        let u2 = Double.random(in: 0..<1, using: &rng)
        return sqrt(-2 * log(u1)) * cos(2 * .pi * u2)
    }

    private func clampedNormal(mean: Double, sd: Double, minValue: Double, maxValue: Double, using rng: inout SystemRandomNumberGenerator) -> Double {
        let value = gaussian(using: &rng) * sd + mean
        return max(minValue, min(maxValue, value))
    }
}
