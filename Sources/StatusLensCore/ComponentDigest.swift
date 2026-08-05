import Foundation

/// What the popover shows for one page's component list. Small pages show
/// everything; large pages (Cloudflare lists every PoP — hundreds of
/// components) collapse to the noteworthy ones plus counts, so the popover
/// height stays bounded no matter the page.
public struct ComponentDigest: Equatable, Sendable {
    /// Components to render as rows (already group-filtered).
    public let shown: [StatuspageSummary.Component]
    /// Noteworthy components that did not fit into `shown`.
    public let hiddenNoteworthyCount: Int
    /// Operational components hidden behind the summary line.
    public let hiddenOperationalCount: Int
    /// All non-group components on the page.
    public let totalCount: Int

    public init(
        shown: [StatuspageSummary.Component],
        hiddenNoteworthyCount: Int,
        hiddenOperationalCount: Int,
        totalCount: Int
    ) {
        self.shown = shown
        self.hiddenNoteworthyCount = hiddenNoteworthyCount
        self.hiddenOperationalCount = hiddenOperationalCount
        self.totalCount = totalCount
    }
}

/// Digest a page's components for display.
///
/// - Pages with at most `showAllThreshold` (non-group) components show all
///   of them, in page order.
/// - Larger pages show only noteworthy components (anything not
///   operational), worst first, capped at `maxShown`; the rest collapse
///   into counts.
public func componentDigest(
    _ components: [StatuspageSummary.Component],
    showAllThreshold: Int = 12,
    maxShown: Int = 10
) -> ComponentDigest {
    let visible = components.filter { !($0.group ?? false) }
    if visible.count <= showAllThreshold {
        return ComponentDigest(
            shown: visible,
            hiddenNoteworthyCount: 0,
            hiddenOperationalCount: 0,
            totalCount: visible.count
        )
    }

    let noteworthy = visible
        .filter { $0.status.severity != .operational }
        .sorted { $0.status.severity > $1.status.severity }
    let shown = Array(noteworthy.prefix(maxShown))
    return ComponentDigest(
        shown: shown,
        hiddenNoteworthyCount: noteworthy.count - shown.count,
        hiddenOperationalCount: visible.count - noteworthy.count,
        totalCount: visible.count
    )
}
