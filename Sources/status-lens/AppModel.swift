import Combine
import Foundation
import StatusLensCore

/// SwiftUI also exports a `Settings` scene; pin the name to our model type
/// for the whole app module.
typealias Settings = StatusLensCore.Settings

/// Observable snapshot shared with the SwiftUI popover / settings views.
/// AppDelegate owns the write side; views read and dispatch via `AppActions`.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var states: [ProfileState] = []
    @Published private(set) var settings: Settings
    @Published private(set) var lastUpdated: Date?

    init(settings: Settings) {
        self.settings = settings
    }

    func update(states: [ProfileState]) {
        self.states = states
        self.lastUpdated = Date()
    }

    func update(settings: Settings) {
        self.settings = settings
    }
}

/// View → app callbacks (kept as closures so views stay decoupled from
/// AppDelegate).
struct AppActions {
    let refresh: () -> Void
    let quit: () -> Void
}
