import XCTest
@testable import StatusLensCore

final class DatesTests: XCTestCase {
    func testParsesFractionalSeconds() throws {
        let date = try XCTUnwrap(parseStatuspageDate("2026-08-05T14:44:00.887Z"))

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 8)
        XCTAssertEqual(parts.day, 5)
        XCTAssertEqual(parts.hour, 14)
        XCTAssertEqual(parts.minute, 44)
        XCTAssertEqual(parts.second, 0)
    }

    func testFractionalAndPlainFormsAgree() throws {
        let fractional = try XCTUnwrap(parseStatuspageDate("2026-08-05T14:44:00.887Z"))
        let plain = try XCTUnwrap(parseStatuspageDate("2026-08-05T14:44:00Z"))
        XCTAssertEqual(fractional.timeIntervalSince(plain), 0.887, accuracy: 0.001)
    }

    func testNilAndGarbageReturnNil() {
        XCTAssertNil(parseStatuspageDate(nil))
        XCTAssertNil(parseStatuspageDate("yesterday"))
        XCTAssertNil(parseStatuspageDate(""))
    }
}
