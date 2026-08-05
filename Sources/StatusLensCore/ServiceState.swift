import Foundation

/// Unified per-profile state shown in the menu bar.
///
/// Severity order (for worst-of aggregation): operational < maintenance <
/// unknown < minor < major < critical. `unknown` (fetch failure or an
/// unparseable indicator) outranks healthy states — a blind watcher must be
/// visible — but never outranks a real outage.
public enum ServiceStatus: Int, Equatable, Comparable, CaseIterable, Sendable {
    case operational = 0
    case maintenance = 1
    case unknown = 2
    case minor = 3
    case major = 4
    case critical = 5

    public static func < (lhs: ServiceStatus, rhs: ServiceStatus) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(indicator: StatusIndicator) {
        switch indicator {
        case .none: self = .operational
        case .minor: self = .minor
        case .major: self = .major
        case .critical: self = .critical
        case .maintenance: self = .maintenance
        case .unknown: self = .unknown
        }
    }

    /// SF Symbols name for the menu bar / popover (plan C: label + shape).
    public var symbolName: String {
        switch self {
        case .operational: return "checkmark"
        case .maintenance: return "wrench.and.screwdriver"
        case .unknown: return "questionmark"
        case .minor: return "exclamationmark.triangle"
        case .major, .critical: return "xmark"
        }
    }

    /// True when the state deserves attention (counted in worst-of mode).
    public var isDegraded: Bool {
        switch self {
        case .operational, .maintenance: return false
        case .unknown, .minor, .major, .critical: return true
        }
    }
}

/// Snapshot of one profile after a polling round.
public struct ProfileState: Equatable, Sendable {
    public let profile: Profile
    public let status: ServiceStatus
    /// Present when the fetch succeeded.
    public let summary: StatuspageSummary?
    /// Human-readable fetch failure, when `summary` is nil.
    public let errorDescription: String?

    public init(
        profile: Profile,
        status: ServiceStatus,
        summary: StatuspageSummary? = nil,
        errorDescription: String? = nil
    ) {
        self.profile = profile
        self.status = status
        self.summary = summary
        self.errorDescription = errorDescription
    }

    public static func fetched(_ profile: Profile, summary: StatuspageSummary) -> ProfileState {
        ProfileState(
            profile: profile,
            status: ServiceStatus(indicator: summary.status.indicator),
            summary: summary
        )
    }

    public static func unreachable(_ profile: Profile, error: String) -> ProfileState {
        ProfileState(profile: profile, status: .unknown, errorDescription: error)
    }
}

/// Worst-of aggregation across all watched profiles.
public struct WorstOf: Equatable, Sendable {
    public let status: ServiceStatus
    /// Number of profiles currently degraded (unknown / minor / major / critical).
    public let degradedCount: Int

    public init(status: ServiceStatus, degradedCount: Int) {
        self.status = status
        self.degradedCount = degradedCount
    }
}

/// Aggregate states for the worst-of display mode. An empty input (no enabled
/// profiles) aggregates to `.unknown` — there is nothing the watcher can claim.
public func worstOf(_ states: [ProfileState]) -> WorstOf {
    guard let worst = states.map(\.status).max() else {
        return WorstOf(status: .unknown, degradedCount: 0)
    }
    return WorstOf(status: worst, degradedCount: states.filter(\.status.isDegraded).count)
}
