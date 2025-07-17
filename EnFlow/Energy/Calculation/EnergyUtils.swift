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

/// Range of hours visible in energy graphs based on the user's profile.
/// - Parameters:
///   - profile: User settings with wake/sleep times. Pass `nil` to always use
///     the provided default range.
///   - defaultRange: Fallback range when the profile doesn't specify a custom
///     window or wake/sleep are equal.
///   - calendar: Calendar used to extract hour components.
/// - Returns: A half-open range of integer hours. If the sleep time occurs
///   before the wake time, the upper bound may exceed 24 so the caller can wrap
///   indices using `% 24`.
func visibleRange(for profile: UserProfile?,
                  default defaultRange: Range<Int>,
                  calendar: Calendar = .current) -> Range<Int> {
    guard let p = profile else { return defaultRange }

    let wake = calendar.component(.hour, from: p.typicalWakeTime)
    let sleep = calendar.component(.hour, from: p.typicalSleepTime)

    // If unset or equal, treat as no custom window
    guard wake != sleep else { return defaultRange }

    let defWake = calendar.component(.hour, from: UserProfile.default.typicalWakeTime)
    let defSleep = calendar.component(.hour, from: UserProfile.default.typicalSleepTime)
    let usingDefaults = wake == defWake && sleep == defSleep
    guard !usingDefaults else { return defaultRange }

    if sleep > wake { return wake..<sleep }
    // Cross-midnight (e.g. 23 → 7) wraps past 24
    return wake..<(sleep + 24)
}

/// Returns elements from `wave` in the order specified by `range`, wrapping
/// indices that exceed the array bounds.
func energySlice(_ wave: [Double], range: Range<Int>) -> [Double] {
    guard !wave.isEmpty else { return [] }
    return range.map { wave[$0 % wave.count] }
}
