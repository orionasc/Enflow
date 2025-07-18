import XCTest
@testable import EnFlow

final class EnergyForecastModelTests: XCTestCase {
    func testBedWakeShapingVariability() {
        let cal = Calendar.current
        ForecastCache.shared.clearAllCachedData()
        let model = EnergyForecastModel()

        let startDay = cal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        var profile = UserProfile.default
        profile.typicalWakeTime = cal.date(bySettingHour: 7, minute: 0, second: 0, of: startDay)!
        profile.typicalSleepTime = cal.date(bySettingHour: 23, minute: 0, second: 0, of: startDay)!

        var health: [HealthEvent] = []
        for i in 0..<30 {
            let d = cal.date(byAdding: .day, value: i, to: startDay)!
            let he = HealthEvent(
                date: d,
                hrv: 80,
                restingHR: 55,
                heartRate: 60,
                sleepEfficiency: 90,
                sleepLatency: 10,
                deepSleep: 100,
                remSleep: 90,
                timeInBed: 450,
                steps: 8000,
                calories: 2000,
                availableMetrics: Set(MetricType.allCases),
                hasSamples: true
            )
            health.append(he)
        }

        var magnitudes: [Double] = []
        for i in 0..<30 {
            let day = cal.date(byAdding: .day, value: i, to: startDay)!
            guard let forecast = model.forecast(for: day, health: health, events: [], profile: profile) else {
                XCTFail("No forecast")
                return
            }
            let wave = forecast.values
            let bedHr = cal.component(.hour, from: profile.typicalSleepTime)
            let wakeHr = cal.component(.hour, from: profile.typicalWakeTime)
            XCTAssertLessThanOrEqual(wave[23], 0.50)
            let preBed1 = (bedHr - 1 + 24) % 24
            let preBed3 = (bedHr - 3 + 24) % 24
            XCTAssertLessThan(wave[preBed1], wave[preBed3])
            XCTAssertGreaterThan(wave[wakeHr], wave[(wakeHr - 1 + 24) % 24])
            magnitudes.append(wave[preBed3] - wave[preBed1])
        }

        let mean = magnitudes.reduce(0, +) / Double(magnitudes.count)
        let variance = magnitudes.reduce(0) { $0 + pow($1 - mean, 2) } / Double(magnitudes.count)
        let stdDev = sqrt(variance)
        XCTAssertGreaterThan(stdDev, 0.01)
    }
}
