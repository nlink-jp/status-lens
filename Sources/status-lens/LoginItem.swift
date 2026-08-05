import Foundation
import ServiceManagement

/// SMAppService launch-at-login wrapper. Registration requires a real app
/// bundle; the bare dev binary reports unavailable instead of failing.
@MainActor
enum LoginItem {
    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    static var isEnabled: Bool {
        guard isAvailable else { return false }
        return SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
