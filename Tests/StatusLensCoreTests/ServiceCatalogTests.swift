import XCTest
@testable import StatusLensCore

final class ServiceCatalogTests: XCTestCase {
    func testClaudeLeadsTheCatalog() {
        XCTAssertEqual(ServiceCatalog.entries.first?.name, "Claude")
    }

    func testURLsAreUniqueHTTPSWithHost() {
        var seen = Set<URL>()
        for entry in ServiceCatalog.entries {
            XCTAssertTrue(seen.insert(entry.baseURL).inserted, "duplicate URL: \(entry.baseURL)")
            XCTAssertEqual(entry.baseURL.scheme, "https")
            XCTAssertNotNil(entry.baseURL.host)
            XCTAssertTrue(entry.baseURL.path.isEmpty, "base URL must be a page root: \(entry.baseURL)")
        }
    }

    func testLabelsAreUniqueAndShort() {
        var seen = Set<String>()
        for entry in ServiceCatalog.entries {
            XCTAssertTrue(seen.insert(entry.label).inserted, "duplicate label: \(entry.label)")
            XCTAssertTrue((1...3).contains(entry.label.count), "label out of range: \(entry.label)")
        }
    }

    func testPresetsAgreeWithCatalog() {
        for preset in Profile.presets {
            let entry = ServiceCatalog.entries.first { $0.baseURL == preset.baseURL }
            XCTAssertNotNil(entry, "preset \(preset.name) missing from catalog")
            XCTAssertEqual(entry?.label, preset.label)
        }
    }

    func testMakeProfileCarriesEntryFields() {
        let entry = ServiceCatalog.entries[0]
        let profile = entry.makeProfile()
        XCTAssertEqual(profile.name, entry.name)
        XCTAssertEqual(profile.baseURL, entry.baseURL)
        XCTAssertEqual(profile.label, entry.label)
        XCTAssertTrue(profile.enabled)
        XCTAssertTrue(profile.notify)
    }
}
