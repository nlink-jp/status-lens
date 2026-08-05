import Foundation

/// One known Statuspage-hosted service offered in the "Add profile" menu.
public struct CatalogEntry: Equatable, Sendable, Identifiable {
    public let name: String
    public let baseURL: URL
    /// Curated menu bar label, unique across the catalog.
    public let label: String

    public var id: String { baseURL.absoluteString }

    public init(name: String, baseURL: URL, label: String) {
        self.name = name
        self.baseURL = baseURL
        self.label = label
    }

    public func makeProfile(enabled: Bool = true) -> Profile {
        Profile(name: name, baseURL: baseURL, label: label, enabled: enabled, notify: true)
    }
}

/// Built-in directory of known Statuspage-hosted status pages. Every URL was
/// probed live against `/api/v2/status.json` on 2026-08-06 — only pages that
/// actually answer the Statuspage API belong here (e.g. PagerDuty's page does
/// not and is deliberately absent). Claude leads as the house default; the
/// rest are alphabetical.
public enum ServiceCatalog {
    public static let entries: [CatalogEntry] = [
        CatalogEntry(name: "Claude", baseURL: URL(string: "https://status.claude.com")!, label: "CL"),
        CatalogEntry(name: "Atlassian", baseURL: URL(string: "https://status.atlassian.com")!, label: "AT"),
        CatalogEntry(name: "CircleCI", baseURL: URL(string: "https://status.circleci.com")!, label: "CC"),
        CatalogEntry(name: "Cloudflare", baseURL: URL(string: "https://www.cloudflarestatus.com")!, label: "CF"),
        CatalogEntry(name: "Datadog (US1)", baseURL: URL(string: "https://status.datadoghq.com")!, label: "DD"),
        CatalogEntry(name: "DigitalOcean", baseURL: URL(string: "https://status.digitalocean.com")!, label: "DO"),
        CatalogEntry(name: "Discord", baseURL: URL(string: "https://discordstatus.com")!, label: "DC"),
        CatalogEntry(name: "Dropbox", baseURL: URL(string: "https://status.dropbox.com")!, label: "DB"),
        CatalogEntry(name: "Figma", baseURL: URL(string: "https://status.figma.com")!, label: "FG"),
        CatalogEntry(name: "GitHub", baseURL: URL(string: "https://www.githubstatus.com")!, label: "GH"),
        CatalogEntry(name: "New Relic", baseURL: URL(string: "https://status.newrelic.com")!, label: "NR"),
        CatalogEntry(name: "npm", baseURL: URL(string: "https://status.npmjs.org")!, label: "NPM"),
        CatalogEntry(name: "OpenAI", baseURL: URL(string: "https://status.openai.com")!, label: "OA"),
        CatalogEntry(name: "Reddit", baseURL: URL(string: "https://www.redditstatus.com")!, label: "RD"),
        CatalogEntry(name: "SendGrid", baseURL: URL(string: "https://status.sendgrid.com")!, label: "SG"),
        CatalogEntry(name: "Twilio", baseURL: URL(string: "https://status.twilio.com")!, label: "TW"),
        CatalogEntry(name: "Zoom", baseURL: URL(string: "https://status.zoom.us")!, label: "ZM"),
    ]
}
