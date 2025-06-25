import Foundation

enum UserProfileStore {
    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("UserProfile.json")
    }

    static func load() -> UserProfile {
        guard let data = try? Data(contentsOf: fileURL),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile.default
        }
        return profile
    }

    static func save(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }
}
