import Foundation

struct UserProfile: Codable, Equatable {
    enum Chronotype: String, CaseIterable, Identifiable, Codable {
        case morning
        case Afternoon
        case evening
        var id: String { rawValue }
    }

    var caffeineMgPerDay: Int
    var caffeineMorning: Bool
    var caffeineAfternoon: Bool
    var caffeineEvening: Bool
    var exerciseFrequency: Int
    var typicalWakeTime: Date
    var typicalSleepTime: Date
    var usesSleepAid: Bool
    var screensBeforeBed: Bool
    var mealsRegular: Bool
    var chronotype: Chronotype
    var lastUpdated: Date
    var notes: String?
}

extension UserProfile {
    static var `default`: UserProfile {
        let cal = Calendar.current
        let wake = cal.date(bySettingHour: 7, minute: 0, second: 0, of: Date())!
        let sleep = cal.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
        return UserProfile(
            caffeineMgPerDay: 0,
            caffeineMorning: false,
            caffeineAfternoon: false,
            caffeineEvening: false,
            exerciseFrequency: 3,
            typicalWakeTime: wake,
            typicalSleepTime: sleep,
            usesSleepAid: false,
            screensBeforeBed: true,
            mealsRegular: true,
            chronotype: .Afternoon,
            lastUpdated: Date(),
            notes: nil
        )
    }

    func debugSummary() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return "Caffeine: \(caffeineMgPerDay)mg/day (M:\(caffeineMorning), A:\(caffeineAfternoon), E:\(caffeineEvening)). " +
        "Wake \(fmt.string(from: typicalWakeTime)), Sleep \(fmt.string(from: typicalSleepTime)), " +
        "Exercise \(exerciseFrequency)x/week, Chronotype \(chronotype.rawValue)."
    }
}
