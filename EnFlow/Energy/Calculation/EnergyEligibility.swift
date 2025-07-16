import Foundation

/// Returns `true` if a HealthEvent contains the minimum metrics needed to
/// compute a reliable energy score.
func isEnergyEligible(_ event: HealthEvent) -> Bool {
    let required: Set<MetricType> = [
        .stepCount,
        .activeEnergyBurned,
        .heartRate,
        .timeInBed
    ]
    return required.isSubset(of: event.availableMetrics)
}

/// Returns the set of required metrics missing from this event.
func missingRequiredMetrics(_ event: HealthEvent) -> [MetricType] {
    let required: Set<MetricType> = [
        .stepCount,
        .activeEnergyBurned,
        .heartRate,
        .timeInBed
    ]
    return Array(required.subtracting(event.availableMetrics))
}
