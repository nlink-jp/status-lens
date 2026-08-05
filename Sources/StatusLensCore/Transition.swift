import Foundation

/// Notification-relevant change between two observations of one profile.
///
/// Notifications fire only on crossings (RFP: 悪化クロス時のみ):
/// - `degraded`: severity increased into a degraded state — includes a
///   worsening within degraded states (minor → major).
/// - `recovered`: left the degraded states (→ operational or maintenance).
/// - `none`: everything else, including the first observation (no baseline),
///   unchanged states, improvements that are still degraded (critical →
///   minor), and healthy↔maintenance moves.
public enum StatusTransition: Equatable, Sendable {
    case degraded(from: ServiceStatus, to: ServiceStatus)
    case recovered(from: ServiceStatus, to: ServiceStatus)
    case none
}

public func statusTransition(from old: ServiceStatus?, to new: ServiceStatus) -> StatusTransition {
    guard let old, old != new else { return .none }
    if new.isDegraded && new > old {
        return .degraded(from: old, to: new)
    }
    if old.isDegraded && !new.isDegraded {
        return .recovered(from: old, to: new)
    }
    return .none
}
