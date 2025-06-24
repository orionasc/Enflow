import Foundation

// MARK: - SimulatedHealthLoader
struct SimulatedHealthLoader {
    static func loadSimulatedHealthEvents(daysBack: Int) -> [HealthEvent] {
        // Locate CSV in bundle or documents
        let fm = FileManager.default
        let bundleURL = Bundle.main.url(forResource: "simulatedData", withExtension: "csv")
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("simulatedData.csv")
        guard let url = bundleURL ?? docsURL,
              let csv = try? String(contentsOf: url) else { return [] }

        let lines = csv.split(whereSeparator: \n.isNewline)
        guard lines.count > 1 else { return [] }

        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd HH:mm"
        dateFmt.timeZone = TimeZone.current
        var byDay: [Date: DayAcc] = [:]
        let cal = Calendar.current

        for line in lines.dropFirst() {
            let cols = line.split(separator: ",", omittingEmptySubsequences: false)
            guard cols.count >= 15, let ts = dateFmt.date(from: String(cols[0])) else { continue }
            let day = cal.startOfDay(for: ts)
            var acc = byDay[day] ?? DayAcc()

            if let v = Double(cols[1]) { acc.steps += Int(v); acc.metrics.insert(.stepCount) }
            if let v = Double(cols[2]) { acc.restHRTotal += v; acc.restHRCount += 1; acc.metrics.insert(.restingHR) }
            if let v = Double(cols[3]) { acc.calories += v; acc.metrics.insert(.activeEnergyBurned) }
            if let v = Double(cols[4]) { acc.hrvTotal += v; acc.hrvCount += 1; acc.metrics.insert(.heartRateVariabilitySDNN) }
            // Sleep-related columns might be empty
            if let v = Double(cols[11]) { acc.sleepEffTotal += v; acc.sleepEffCount += 1; acc.metrics.insert(.sleepEfficiency) }
            if let v = Double(cols[12]) { acc.sleepLatTotal += v; acc.sleepLatCount += 1; acc.metrics.insert(.sleepLatency) }
            if let v = Double(cols[13]) { acc.deepSleep += v; acc.metrics.insert(.deepSleep) }
            if let v = Double(cols[14]) { acc.remSleep += v; acc.metrics.insert(.remSleep) }

            byDay[day] = acc
        }

        let sortedDays = byDay.keys.sorted()
        let startIndex = max(0, sortedDays.count - daysBack)
        return sortedDays[startIndex...].compactMap { day in
            guard let acc = byDay[day] else { return nil }
            let steps = acc.steps
            let restHR = acc.restHRCount > 0 ? acc.restHRTotal / Double(acc.restHRCount) : 0
            let hrv = acc.hrvCount > 0 ? acc.hrvTotal / Double(acc.hrvCount) : 0
            let eff = acc.sleepEffCount > 0 ? acc.sleepEffTotal / Double(acc.sleepEffCount) : 0
            let lat = acc.sleepLatCount > 0 ? acc.sleepLatTotal / Double(acc.sleepLatCount) : 0
            return HealthEvent(
                date: day,
                hrv: hrv,
                restingHR: restHR,
                sleepEfficiency: eff,
                sleepLatency: lat,
                deepSleep: acc.deepSleep,
                remSleep: acc.remSleep,
                steps: steps,
                calories: acc.calories,
                availableMetrics: acc.metrics,
                hasSamples: !acc.metrics.isEmpty
            )
        }
    }
}

private struct DayAcc {
    var steps: Int = 0
    var calories: Double = 0
    var restHRTotal: Double = 0
    var restHRCount: Int = 0
    var hrvTotal: Double = 0
    var hrvCount: Int = 0
    var sleepEffTotal: Double = 0
    var sleepEffCount: Int = 0
    var sleepLatTotal: Double = 0
    var sleepLatCount: Int = 0
    var deepSleep: Double = 0
    var remSleep: Double = 0
    var metrics: Set<MetricType> = []
}
