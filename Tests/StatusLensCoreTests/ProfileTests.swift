import XCTest
@testable import StatusLensCore

final class ProfileTests: XCTestCase {
    func testSuggestLabelPrefersUppercaseLetters() {
        XCTAssertEqual(Profile.suggestLabel(for: "GitHub"), "GH")
        XCTAssertEqual(Profile.suggestLabel(for: "OpenAI"), "OA")
    }

    func testSuggestLabelFallsBackToLeadingCharacters() {
        XCTAssertEqual(Profile.suggestLabel(for: "Claude"), "CL")
        XCTAssertEqual(Profile.suggestLabel(for: "Dropbox"), "DR")
        XCTAssertEqual(Profile.suggestLabel(for: "iCloud"), "IC")
        XCTAssertEqual(Profile.suggestLabel(for: "x"), "X")
    }

    func testSuggestLabelHandlesDegenerateNames() {
        XCTAssertEqual(Profile.suggestLabel(for: ""), "??")
        XCTAssertEqual(Profile.suggestLabel(for: "!!!"), "??")
    }

    func testNormalizeLabelTrimsAndClamps() {
        XCTAssertEqual(Profile.normalizeLabel(" CLDX ", fallbackName: "Claude"), "CLD")
        XCTAssertEqual(Profile.normalizeLabel("", fallbackName: "GitHub"), "GH")
    }

    func testSummaryURL() {
        XCTAssertEqual(
            Profile.claudePreset.summaryURL.absoluteString,
            "https://status.claude.com/api/v2/summary.json"
        )
    }

    func testPresets() {
        XCTAssertEqual(Profile.presets.count, 2)
        XCTAssertTrue(Profile.claudePreset.enabled)
        XCTAssertFalse(Profile.githubPreset.enabled)
        XCTAssertEqual(Profile.claudePreset.label, "CL")
        XCTAssertEqual(Profile.githubPreset.label, "GH")
        XCTAssertNotEqual(Profile.claudePreset.id, Profile.githubPreset.id)
    }

    func testCodableRoundTrip() throws {
        let original = Profile(
            name: "Cloudflare",
            baseURL: URL(string: "https://www.cloudflarestatus.com")!,
            label: "CF",
            enabled: true,
            notify: false
        )
        let decoded = try JSONDecoder().decode(
            Profile.self,
            from: JSONEncoder().encode(original)
        )
        XCTAssertEqual(decoded, original)
    }
}
