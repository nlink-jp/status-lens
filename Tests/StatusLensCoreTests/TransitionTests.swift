import XCTest
@testable import StatusLensCore

final class TransitionTests: XCTestCase {
    func testFirstObservationNeverNotifies() {
        XCTAssertEqual(statusTransition(from: nil, to: .critical), .none)
        XCTAssertEqual(statusTransition(from: nil, to: .operational), .none)
    }

    func testUnchangedStateIsNone() {
        for status in ServiceStatus.allCases {
            XCTAssertEqual(statusTransition(from: status, to: status), .none)
        }
    }

    func testDegradationFiresOnRisingCross() {
        XCTAssertEqual(
            statusTransition(from: .operational, to: .major),
            .degraded(from: .operational, to: .major)
        )
        XCTAssertEqual(
            statusTransition(from: .operational, to: .unknown),
            .degraded(from: .operational, to: .unknown)
        )
    }

    func testWorseningWithinDegradedFires() {
        XCTAssertEqual(
            statusTransition(from: .minor, to: .critical),
            .degraded(from: .minor, to: .critical)
        )
    }

    func testImprovementWithinDegradedIsSilent() {
        XCTAssertEqual(statusTransition(from: .critical, to: .minor), .none)
    }

    func testRecoveryFiresWhenLeavingDegraded() {
        XCTAssertEqual(
            statusTransition(from: .major, to: .operational),
            .recovered(from: .major, to: .operational)
        )
        XCTAssertEqual(
            statusTransition(from: .minor, to: .maintenance),
            .recovered(from: .minor, to: .maintenance)
        )
    }

    func testMaintenanceMovesAreSilent() {
        XCTAssertEqual(statusTransition(from: .operational, to: .maintenance), .none)
        XCTAssertEqual(statusTransition(from: .maintenance, to: .operational), .none)
    }
}
