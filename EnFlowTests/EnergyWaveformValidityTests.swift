import XCTest
@testable import EnFlow

final class EnergyWaveformValidityTests: XCTestCase {
    func testSummaryAndForecastWaveform() {
        let cal = Calendar.current
        let day = cal.date(from: DateComponents(year: 2025, month: 1, day: 1))!
        var profile = UserProfile.default
        profile.typicalWakeTime = cal.date(bySettingHour: 7, minute: 0, second: 0, of: day)!
        profile.typicalSleepTime = cal.date(bySettingHour: 23, minute: 0, second: 0, of: day)!

        let h = HealthEvent(
            date: day,
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

        let summary = EnergySummaryEngine.shared.summarize(day: day,
                                                           healthEvents: [h],
                                                           calendarEvents: [],
                                                           profile: profile)
        XCTAssertNil(summary.warning)
        XCTAssertEqual(summary.hourlyWaveform.count, 24)
        for v in summary.hourlyWaveform {
            XCTAssertFalse(v.isNaN)
            XCTAssertGreaterThanOrEqual(v, 0)
            XCTAssertLessThanOrEqual(v, 1)
        }

        let model = EnergyForecastModel()
        guard let forecast = model.forecast(for: day,
                                             health: [h],
                                             events: [],
                                             profile: profile) else {
            XCTFail("No forecast")
            return
        }
        XCTAssertEqual(forecast.values.count, 24)
        for v in forecast.values {
            XCTAssertFalse(v.isNaN)
            XCTAssertGreaterThanOrEqual(v, 0)
            XCTAssertLessThanOrEqual(v, 1)
        }
    }
}

