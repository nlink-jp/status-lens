import XCTest
@testable import StatusLensCore

final class AggregationTests: XCTestCase {
    private func state(_ status: ServiceStatus, name: String = "X") -> ProfileState {
        ProfileState(
            profile: Profile(name: name, baseURL: URL(string: "https://x.example")!, label: "XX"),
            status: status
        )
    }

    func testSeverityOrdering() {
        XCTAssertLessThan(ServiceStatus.operational, .maintenance)
        XCTAssertLessThan(ServiceStatus.maintenance, .unknown)
        XCTAssertLessThan(ServiceStatus.unknown, .minor)
        XCTAssertLessThan(ServiceStatus.minor, .major)
        XCTAssertLessThan(ServiceStatus.major, .critical)
    }

    func testWorstOfEmptyIsUnknown() {
        XCTAssertEqual(worstOf([]), WorstOf(status: .unknown, degradedCount: 0))
    }

    func testWorstOfPicksMaximumSeverity() {
        let result = worstOf([state(.operational), state(.minor), state(.major)])
        XCTAssertEqual(result.status, .major)
        XCTAssertEqual(result.degradedCount, 2)
    }

    func testMaintenanceIsNotDegraded() {
        let result = worstOf([state(.maintenance), state(.operational)])
        XCTAssertEqual(result.status, .maintenance)
        XCTAssertEqual(result.degradedCount, 0)
    }

    func testUnreachableSurfacesOverHealthyButNotOverOutage() {
        XCTAssertEqual(worstOf([state(.unknown), state(.operational)]).status, .unknown)
        XCTAssertEqual(worstOf([state(.unknown), state(.critical)]).status, .critical)
        XCTAssertEqual(worstOf([state(.unknown), state(.operational)]).degradedCount, 1)
    }

    func testIndicatorMapping() {
        XCTAssertEqual(ServiceStatus(indicator: .none), .operational)
        XCTAssertEqual(ServiceStatus(indicator: .minor), .minor)
        XCTAssertEqual(ServiceStatus(indicator: .major), .major)
        XCTAssertEqual(ServiceStatus(indicator: .critical), .critical)
        XCTAssertEqual(ServiceStatus(indicator: .maintenance), .maintenance)
        XCTAssertEqual(ServiceStatus(indicator: .unknown("x")), .unknown)
    }

    func testSymbolNames() {
        XCTAssertEqual(ServiceStatus.operational.symbolName, "checkmark")
        XCTAssertEqual(ServiceStatus.minor.symbolName, "exclamationmark.triangle")
        XCTAssertEqual(ServiceStatus.major.symbolName, "xmark")
        XCTAssertEqual(ServiceStatus.critical.symbolName, "xmark")
        XCTAssertEqual(ServiceStatus.maintenance.symbolName, "wrench.and.screwdriver")
        XCTAssertEqual(ServiceStatus.unknown.symbolName, "questionmark")
    }

    func testComponentSeverityMapping() {
        XCTAssertEqual(ComponentStatus.operational.severity, .operational)
        XCTAssertEqual(ComponentStatus.degradedPerformance.severity, .minor)
        XCTAssertEqual(ComponentStatus.partialOutage.severity, .major)
        XCTAssertEqual(ComponentStatus.majorOutage.severity, .critical)
        XCTAssertEqual(ComponentStatus.underMaintenance.severity, .maintenance)
        XCTAssertEqual(ComponentStatus.unknown("x").severity, .unknown)
    }

    func testFetchedAndUnreachableFactories() throws {
        let summary = try StatuspageClient.decodeSummary(DecodeTests.summaryFixture)
        let profile = Profile.claudePreset

        let fetched = ProfileState.fetched(profile, summary: summary)
        XCTAssertEqual(fetched.status, .major)
        XCTAssertNil(fetched.errorDescription)

        let unreachable = ProfileState.unreachable(profile, error: "timeout")
        XCTAssertEqual(unreachable.status, .unknown)
        XCTAssertNil(unreachable.summary)
        XCTAssertEqual(unreachable.errorDescription, "timeout")
    }
}
