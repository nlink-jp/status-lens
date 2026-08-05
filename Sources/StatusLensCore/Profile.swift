import Foundation

/// One watched Statuspage-hosted status page.
public struct Profile: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    /// Page root, e.g. `https://status.claude.com`. The API path is derived.
    public var baseURL: URL
    /// Short menu bar label, 1–3 characters.
    public var label: String
    public var enabled: Bool
    public var notify: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        baseURL: URL,
        label: String,
        enabled: Bool = true,
        notify: Bool = true
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.label = Self.normalizeLabel(label, fallbackName: name)
        self.enabled = enabled
        self.notify = notify
    }

    /// `/api/v2/summary.json` for this page.
    public var summaryURL: URL {
        baseURL.appendingPathComponent("api/v2/summary.json")
    }

    /// Clamp a label to 1–3 visible characters; empty input falls back to a
    /// suggestion derived from the name.
    public static func normalizeLabel(_ label: String, fallbackName: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return suggestLabel(for: fallbackName) }
        return String(trimmed.prefix(3))
    }

    /// Suggest a 2-character label from a service name: prefer the word's
    /// uppercase letters ("GitHub" → "GH"), otherwise the first two
    /// alphanumerics uppercased ("Claude" → "CL").
    public static func suggestLabel(for name: String) -> String {
        let alnum = name.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        let uppers = alnum.filter { CharacterSet.uppercaseLetters.contains($0) }
        let source = uppers.count >= 2 ? uppers : alnum
        let label = String(String.UnicodeScalarView(source.prefix(2))).uppercased()
        return label.isEmpty ? "??" : label
    }
}

extension Profile {
    /// Built-in presets. IDs are fixed so user edits survive re-registration.
    public static let claudePreset = Profile(
        id: UUID(uuidString: "F0A34E5C-0000-4000-8000-000000000001")!,
        name: "Claude",
        baseURL: URL(string: "https://status.claude.com")!,
        label: "CL",
        enabled: true
    )

    public static let githubPreset = Profile(
        id: UUID(uuidString: "F0A34E5C-0000-4000-8000-000000000002")!,
        name: "GitHub",
        baseURL: URL(string: "https://www.githubstatus.com")!,
        label: "GH",
        enabled: false
    )

    public static let presets: [Profile] = [claudePreset, githubPreset]
}
