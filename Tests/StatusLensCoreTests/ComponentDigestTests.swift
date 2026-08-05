import XCTest
@testable import StatusLensCore

final class ComponentDigestTests: XCTestCase {
    private func component(
        _ name: String,
        _ status: ComponentStatus = .operational,
        group: Bool = false
    ) -> StatuspageSummary.Component {
        StatuspageSummary.Component(id: name, name: name, status: status, group: group)
    }

    func testSmallPageShowsEverythingInPageOrder() {
        let components = [
            component("a"), component("b", .partialOutage), component("c"),
        ]
        let digest = componentDigest(components)
        XCTAssertEqual(digest.shown.map(\.name), ["a", "b", "c"])
        XCTAssertEqual(digest.hiddenNoteworthyCount, 0)
        XCTAssertEqual(digest.hiddenOperationalCount, 0)
        XCTAssertEqual(digest.totalCount, 3)
    }

    func testGroupContainersAreExcluded() {
        let components = [component("group", group: true), component("a")]
        let digest = componentDigest(components)
        XCTAssertEqual(digest.shown.map(\.name), ["a"])
        XCTAssertEqual(digest.totalCount, 1)
    }

    func testLargeHealthyPageCollapsesToCountsOnly() {
        let components = (0..<300).map { component("pop\($0)") }
        let digest = componentDigest(components)
        XCTAssertTrue(digest.shown.isEmpty)
        XCTAssertEqual(digest.hiddenNoteworthyCount, 0)
        XCTAssertEqual(digest.hiddenOperationalCount, 300)
        XCTAssertEqual(digest.totalCount, 300)
    }

    func testLargePageShowsNoteworthyWorstFirstCapped() {
        var components = (0..<300).map { component("pop\($0)") }
        components.append(component("minor1", .degradedPerformance))
        components.append(component("outage", .majorOutage))
        components.append(component("minor2", .degradedPerformance))

        let digest = componentDigest(components)
        XCTAssertEqual(digest.shown.first?.name, "outage")
        XCTAssertEqual(digest.shown.count, 3)
        XCTAssertEqual(digest.hiddenNoteworthyCount, 0)
        XCTAssertEqual(digest.hiddenOperationalCount, 300)
        XCTAssertEqual(digest.totalCount, 303)
    }

    func testLargePageCapsNoteworthyList() {
        var components = (0..<50).map { component("ok\($0)") }
        components.append(contentsOf: (0..<15).map { component("bad\($0)", .partialOutage) })

        let digest = componentDigest(components, maxShown: 10)
        XCTAssertEqual(digest.shown.count, 10)
        XCTAssertEqual(digest.hiddenNoteworthyCount, 5)
        XCTAssertEqual(digest.hiddenOperationalCount, 50)
    }

    func testMaintenanceCountsAsNoteworthy() {
        var components = (0..<20).map { component("ok\($0)") }
        components.append(component("mnt", .underMaintenance))

        let digest = componentDigest(components)
        XCTAssertEqual(digest.shown.map(\.name), ["mnt"])
        XCTAssertEqual(digest.hiddenOperationalCount, 20)
    }
}
