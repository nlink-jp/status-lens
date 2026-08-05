import XCTest
@testable import StatusLensCore

final class DecodeTests: XCTestCase {
    /// Trimmed but shape-faithful copy of a live status.claude.com response
    /// (probed 2026-08-06).
    static let summaryFixture = Data("""
    {
      "page": {
        "id": "tymt9n04zgry",
        "name": "Claude",
        "url": "https://status.claude.com",
        "time_zone": "Etc/UTC",
        "updated_at": "2026-08-05T14:44:00.887Z"
      },
      "components": [
        {
          "id": "rwppv331jlwc",
          "name": "claude.ai",
          "status": "operational",
          "created_at": "2023-07-11T17:52:24.275Z",
          "updated_at": "2026-08-05T14:14:35.909Z",
          "position": 1,
          "description": null,
          "showcase": true,
          "start_date": "2023-07-11",
          "group_id": null,
          "page_id": "tymt9n04zgry",
          "group": false,
          "only_show_if_degraded": false
        },
        {
          "id": "k8w3r06qmzrp",
          "name": "Claude API (api.anthropic.com)",
          "status": "partial_outage",
          "position": 3,
          "group_id": null,
          "group": false,
          "only_show_if_degraded": false
        }
      ],
      "incidents": [
        {
          "id": "abc123",
          "name": "Elevated errors on Claude API",
          "status": "investigating",
          "impact": "major",
          "created_at": "2026-08-05T13:00:00.000Z",
          "updated_at": "2026-08-05T14:00:00.000Z",
          "shortlink": "https://stspg.io/abc123",
          "incident_updates": [
            {
              "id": "upd1",
              "status": "investigating",
              "body": "We are investigating elevated error rates.",
              "display_at": "2026-08-05T13:00:00.000Z"
            }
          ]
        }
      ],
      "scheduled_maintenances": [
        {
          "id": "mnt1",
          "name": "Database upgrade",
          "status": "scheduled",
          "scheduled_for": "2026-08-10T02:00:00.000Z",
          "scheduled_until": "2026-08-10T04:00:00.000Z",
          "shortlink": "https://stspg.io/mnt1"
        }
      ],
      "status": {
        "indicator": "major",
        "description": "Partial System Outage"
      }
    }
    """.utf8)

    func testDecodeRealShapedSummary() throws {
        let summary = try StatuspageClient.decodeSummary(Self.summaryFixture)

        XCTAssertEqual(summary.page.name, "Claude")
        XCTAssertEqual(summary.page.url, "https://status.claude.com")
        XCTAssertEqual(summary.status.indicator, .major)
        XCTAssertEqual(summary.status.description, "Partial System Outage")

        XCTAssertEqual(summary.components.count, 2)
        XCTAssertEqual(summary.components[0].status, .operational)
        XCTAssertEqual(summary.components[1].status, .partialOutage)

        XCTAssertEqual(summary.incidents.count, 1)
        XCTAssertEqual(summary.incidents[0].impact, "major")
        XCTAssertEqual(summary.incidents[0].incidentUpdates?.first?.status, "investigating")

        XCTAssertEqual(summary.scheduledMaintenances.count, 1)
        XCTAssertEqual(summary.scheduledMaintenances[0].scheduledFor, "2026-08-10T02:00:00.000Z")
    }

    func testUnknownEnumValuesDecodeGracefully() throws {
        let data = Data("""
        {
          "page": {"id": "p", "name": "X", "url": "https://x.example"},
          "components": [
            {"id": "c1", "name": "api", "status": "sharded_outage"}
          ],
          "incidents": [],
          "scheduled_maintenances": [],
          "status": {"indicator": "meltdown", "description": "?"}
        }
        """.utf8)

        let summary = try StatuspageClient.decodeSummary(data)
        XCTAssertEqual(summary.status.indicator, .unknown("meltdown"))
        XCTAssertEqual(summary.components[0].status, .unknown("sharded_outage"))
        XCTAssertEqual(ServiceStatus(indicator: summary.status.indicator), .unknown)
    }

    /// OpenAI's page is Statuspage-compatible but not Atlassian-hosted:
    /// ULID ids, no top-level scheduled_maintenances. Shape captured live
    /// 2026-08-06 — this exact payload once decoded as "unreachable".
    func testStatuspageCompatiblePageWithoutMaintenancesDecodes() throws {
        let data = Data("""
        {
          "page": {
            "id": "01JMDK9XYNY6RXSED6SDWW50WY",
            "name": "OpenAI",
            "url": "https://status.openai.com/",
            "updated_at": "2026-08-05T19:03:27Z"
          },
          "status": {"indicator": "minor", "description": "Partial System Degradation"},
          "components": [
            {"id": "01JMDK9Y1B4V4CE6NA2SVREJ1Q", "name": "API", "status": "operational", "position": 1}
          ],
          "incidents": [
            {
              "id": "01KZ9DMQD2GJ8JJWDN7572RH78",
              "name": "Issues with Custom GPT actions",
              "status": "monitoring",
              "impact": "minor",
              "shortlink": null,
              "updated_at": "2026-08-05T19:03:27Z"
            }
          ]
        }
        """.utf8)

        let summary = try StatuspageClient.decodeSummary(data)
        XCTAssertEqual(summary.page.name, "OpenAI")
        XCTAssertEqual(summary.status.indicator, .minor)
        XCTAssertEqual(summary.components.count, 1)
        XCTAssertEqual(summary.incidents.count, 1)
        XCTAssertNil(summary.incidents[0].shortlink)
        XCTAssertTrue(summary.scheduledMaintenances.isEmpty)
    }

    func testGarbagePayloadThrowsClientError() {
        let data = Data("<html>redirect page</html>".utf8)
        XCTAssertThrowsError(try StatuspageClient.decodeSummary(data)) { error in
            XCTAssertTrue(error is StatuspageClientError)
        }
    }

    func testIndicatorRoundTrip() throws {
        for raw in ["none", "minor", "major", "critical", "maintenance", "future_state"] {
            let indicator = StatusIndicator(rawValue: raw)
            XCTAssertEqual(indicator.rawValue, raw)
        }
    }
}
