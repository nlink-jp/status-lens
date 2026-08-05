import XCTest
@testable import StatusLensCore

private struct StubFetcher: SummaryFetching {
    let handler: @Sendable (Profile) async throws -> StatuspageSummary

    func fetchSummary(for profile: Profile) async throws -> StatuspageSummary {
        try await handler(profile)
    }
}

final class LoadStatesTests: XCTestCase {
    private static func summary(indicator: StatusIndicator) -> StatuspageSummary {
        StatuspageSummary(
            page: .init(id: "p", name: "X", url: "https://x.example", updatedAt: nil),
            status: .init(indicator: indicator, description: "d"),
            components: [],
            incidents: [],
            scheduledMaintenances: []
        )
    }

    func testStatesPreserveInputOrderAndDegradeOnFailure() async {
        let ok = Profile(name: "Alpha", baseURL: URL(string: "https://a.example")!, label: "AL")
        let broken = Profile(name: "Beta", baseURL: URL(string: "https://b.example")!, label: "BE")

        let fetcher = StubFetcher { profile in
            if profile.name == "Beta" { throw StatuspageClientError("timeout") }
            return Self.summary(indicator: .minor)
        }

        let states = await loadStates(profiles: [ok, broken], fetcher: fetcher)

        XCTAssertEqual(states.count, 2)
        XCTAssertEqual(states[0].profile.name, "Alpha")
        XCTAssertEqual(states[0].status, .minor)
        XCTAssertEqual(states[1].profile.name, "Beta")
        XCTAssertEqual(states[1].status, .unknown)
        XCTAssertNotNil(states[1].errorDescription)
    }

    func testDisabledProfilesAreSkipped() async {
        var disabled = Profile(name: "Off", baseURL: URL(string: "https://off.example")!, label: "OF")
        disabled.enabled = false
        let enabled = Profile(name: "On", baseURL: URL(string: "https://on.example")!, label: "ON")

        let fetcher = StubFetcher { _ in Self.summary(indicator: .none) }
        let states = await loadStates(profiles: [disabled, enabled], fetcher: fetcher)

        XCTAssertEqual(states.map(\.profile.name), ["On"])
        XCTAssertEqual(states[0].status, .operational)
    }
}
