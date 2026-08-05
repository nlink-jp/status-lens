import XCTest
@testable import StatusLensCore

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let settings = Settings.default
        XCTAssertEqual(settings.displayMode, .parallel)
        XCTAssertEqual(settings.pollingIntervalSeconds, 60)
        XCTAssertEqual(settings.profiles, Profile.presets)
    }

    func testIntervalClamping() {
        XCTAssertEqual(Settings.clampInterval(5), 30)
        XCTAssertEqual(Settings.clampInterval(60), 60)
        XCTAssertEqual(Settings.clampInterval(99999), 3600)

        let settings = Settings(displayMode: .worst, pollingIntervalSeconds: 1, profiles: [])
        XCTAssertEqual(settings.pollingIntervalSeconds, 30)
    }

    func testEmptyPayloadDecodesToDefaults() throws {
        let settings = try Settings.decoded(from: Data("{}".utf8))
        XCTAssertEqual(settings, .default)
    }

    func testRoundTrip() throws {
        let original = Settings(
            displayMode: .worst,
            pollingIntervalSeconds: 120,
            profiles: [Profile.githubPreset]
        )
        let decoded = try Settings.decoded(from: original.encoded())
        XCTAssertEqual(decoded, original)
    }
}
