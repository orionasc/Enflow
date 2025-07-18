import Foundation

struct UserProfile: Codable, Equatable {
    enum Chronotype: String, CaseIterable, Identifiable, Codable {
        case none
        case morning
        case afternoon
        case evening
        var id: String { rawValue }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            if let value = Chronotype(rawValue: raw.lowercased()) {
                self = value
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid chronotype value \(raw)")
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }

        /// Options presented to the user. Excludes the `none` case used when
        /// the chronotype is cleared.
        static var selectableCases: [Chronotype] { [.morning, .afternoon, .evening] }
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
            chronotype: .afternoon,
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
