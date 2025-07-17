import Foundation

/// Utility math functions used across energy models.
func norm(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
    guard hi > lo else { return 0.5 }
    return max(0.0, min(1.0, (v - lo) / (hi - lo)))
}

/// Activity score peaks near the personal mean step count.
func activityScore(steps: Int, mean: Int = 8000, sd: Int = 3000) -> Double {
    let z = Double(steps - mean) / Double(sd)
    return exp(-0.5 * z * z)
}

/// Projects a partial-day step count to an estimated full-day total so that
/// low morning step counts don’t tank energy scores.
///
/// • If `date` **is today**, it scales the observed steps by `24 / hoursElapsed`.
/// • Otherwise it just returns `steps`.
func projectedSteps(_ steps: Int,
                    for date: Date,
                    calendar: Calendar = .current) -> Int {
    guard calendar.isDateInToday(date) else { return steps }
    let hours = max(1, calendar.component(.hour, from: Date()))   // avoid /0
    let projected = Double(steps) / Double(hours) * 24.0
    return Int(projected.rounded())
}
