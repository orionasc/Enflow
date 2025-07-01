import Foundation

/// Caches forecasted hourly values and prediction accuracy by day.
final class ForecastCache {
    static let shared = ForecastCache()
    private init() {
        load()
    }

    private let waveKey = "ForecastCache.Waves"
    private let accKey  = "ForecastCache.Accuracy"
    private let forecastKey = "ForecastCache.Forecasts"

    private var waves: [String:[Double]] = [:]
    private var accuracy: [String:Double] = [:]
    private var forecasts: [String:DayEnergyForecast] = [:]

    private func load() {
        let d = UserDefaults.standard
        if let wData = d.data(forKey: waveKey),
           let obj = try? JSONDecoder().decode([String:[Double]].self, from: wData) {
            waves = obj
        }
        if let aData = d.data(forKey: accKey),
           let obj = try? JSONDecoder().decode([String:Double].self, from: aData) {
            accuracy = obj
        }
        if let fData = d.data(forKey: forecastKey),
           let obj = try? JSONDecoder().decode([String:DayEnergyForecast].self, from: fData) {
            forecasts = obj
        }
    }

    private func persist() {
        let d = UserDefaults.standard
        if let data = try? JSONEncoder().encode(waves) {
            d.set(data, forKey: waveKey)
        }
        if let data = try? JSONEncoder().encode(accuracy) {
            d.set(data, forKey: accKey)
        }
        if let data = try? JSONEncoder().encode(forecasts) {
            d.set(data, forKey: forecastKey)
        }
    }

    private func key(for date: Date) -> String {
        ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: date))
    }

    func wave(for date: Date) -> [Double]? {
        waves[key(for: date)]
    }

    func saveWave(_ wave: [Double], for date: Date) {
        waves[key(for: date)] = wave
        persist()
    }

    func saveAccuracy(_ value: Double, for date: Date) {
        accuracy[key(for: date)] = value
        persist()
    }

    func accuracy(for date: Date) -> Double? {
        accuracy[key(for: date)]
    }

    func forecast(for date: Date) -> DayEnergyForecast? {
        forecasts[key(for: date)]
    }

    func saveForecast(_ forecast: DayEnergyForecast) {
        forecasts[key(for: forecast.date)] = forecast
        persist()
    }

    /// Average accuracy over the last N days if available.
    func recentAccuracy(days: Int) -> Double? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dates = (0..<days).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let vals = dates.compactMap { accuracy[key(for: $0)] }
        guard !vals.isEmpty else { return nil }
        return vals.reduce(0, +) / Double(vals.count)
    }

    func clearAllCachedData() {
        waves.removeAll()
        accuracy.removeAll()
        forecasts.removeAll()
        persist()
    }
}
