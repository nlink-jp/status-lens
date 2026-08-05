import Foundation
import StatusLensCore

/// UserDefaults-backed persistence for `Settings`. The codec lives in
/// StatusLensCore (`Settings.encoded`/`decoded`) so it stays testable.
@MainActor
final class SettingsStore {
    private static let key = "settings.v1"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> Settings {
        guard
            let data = defaults.data(forKey: Self.key),
            let settings = try? Settings.decoded(from: data)
        else {
            return .default
        }
        return settings
    }

    func save(_ settings: Settings) {
        guard let data = try? settings.encoded() else { return }
        defaults.set(data, forKey: Self.key)
    }
}
