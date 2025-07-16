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
