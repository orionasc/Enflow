import XCTest
@testable import EnFlow

final class UserProfileCodableTests: XCTestCase {
    func testChronotypeEncodingDecoding() throws {
        let profile = UserProfile.default
        let data = try JSONEncoder().encode(profile)
        let newProfile = try JSONDecoder().decode(UserProfile.self, from: data)
        XCTAssertEqual(newProfile.chronotype, .afternoon)

        if var json = String(data: data, encoding: .utf8) {
            json = json.replacingOccurrences(of: "\"afternoon\"", with: "\"Afternoon\"")
            if let oldData = json.data(using: .utf8) {
                let oldProfile = try JSONDecoder().decode(UserProfile.self, from: oldData)
                XCTAssertEqual(oldProfile.chronotype, .afternoon)
            }
        }
    }
}
