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

            let steps = Int(clampedNormal(mean: 8000, sd: 3000, minValue: 2000, maxValue: 13000, using: &rng))
            let hrv = clampedNormal(mean: 65, sd: 20, minValue: 20, maxValue: 120, using: &rng)
            let resting = clampedNormal(mean: 62, sd: 10, minValue: 45, maxValue: 90, using: &rng)
            let sleepHours = clampedNormal(mean: 7.0, sd: 1.5, minValue: 4.0, maxValue: 9.0, using: &rng)
            let deepRatio = clampedNormal(mean: 0.18, sd: 0.08, minValue: 0.05, maxValue: 0.3, using: &rng)
            let remRatio = clampedNormal(mean: 0.22, sd: 0.08, minValue: 0.1, maxValue: 0.4, using: &rng)
            let latency = clampedNormal(mean: 20, sd: 10, minValue: 5, maxValue: 60, using: &rng)
            let efficiency = clampedNormal(mean: 80, sd: 15, minValue: 50, maxValue: 100, using: &rng)
            let activeEnergy = clampedNormal(mean: 800, sd: 250, minValue: 400, maxValue: 1200, using: &rng)

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
