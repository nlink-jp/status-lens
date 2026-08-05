import Foundation

/// Menu bar rendering mode.
public enum DisplayMode: String, Codable, Equatable, Sendable, CaseIterable {
    /// One "label + symbol" entry per watched profile (plan C).
    case parallel
    /// Single indicator showing the worst status + degraded count.
    case worst
}

/// Persisted app settings. Stored as one JSON blob in UserDefaults; fields
/// decode with defaults so older payloads keep working after upgrades.
public struct Settings: Codable, Equatable, Sendable {
    public var displayMode: DisplayMode
    /// Seconds between polling rounds, clamped to 30...3600.
    public var pollingIntervalSeconds: Int
    public var profiles: [Profile]

    public static let `default` = Settings(
        displayMode: .parallel,
        pollingIntervalSeconds: 60,
        profiles: Profile.presets
    )

    public init(displayMode: DisplayMode, pollingIntervalSeconds: Int, profiles: [Profile]) {
        self.displayMode = displayMode
        self.pollingIntervalSeconds = Self.clampInterval(pollingIntervalSeconds)
        self.profiles = profiles
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let mode = try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode)
        let interval = try container.decodeIfPresent(Int.self, forKey: .pollingIntervalSeconds)
        let profiles = try container.decodeIfPresent([Profile].self, forKey: .profiles)
        self.init(
            displayMode: mode ?? Self.default.displayMode,
            pollingIntervalSeconds: interval ?? Self.default.pollingIntervalSeconds,
            profiles: profiles ?? Self.default.profiles
        )
    }

    public static func clampInterval(_ seconds: Int) -> Int {
        min(max(seconds, 30), 3600)
    }

    /// Round-trip helpers so persistence stays a pure, testable transform.
    public func encoded() throws -> Data {
        try JSONEncoder().encode(self)
    }

    public static func decoded(from data: Data) throws -> Settings {
        try JSONDecoder().decode(Settings.self, from: data)
    }
}
