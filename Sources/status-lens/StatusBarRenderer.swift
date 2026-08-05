import AppKit
import StatusLensCore

/// Renders profile states into the menu bar title (plan C: horizontal short
/// label + colored SF Symbols shape, dual-encoded so the state survives
/// grayscale and color-vision deficiency).
@MainActor
enum StatusBarRenderer {
    static let labelFont = NSFont.systemFont(ofSize: 12, weight: .medium)

    nonisolated static func color(for status: ServiceStatus) -> NSColor {
        switch status {
        case .operational: return .systemGreen
        case .maintenance: return .systemBlue
        case .unknown: return .systemGray
        case .minor: return .systemYellow
        case .major: return .systemOrange
        case .critical: return .systemRed
        }
    }

    static func attributedTitle(states: [ProfileState], mode: DisplayMode) -> NSAttributedString {
        switch mode {
        case .parallel: return parallelTitle(states: states)
        case .worst: return worstTitle(states: states)
        }
    }

    private static func parallelTitle(states: [ProfileState]) -> NSAttributedString {
        guard !states.isEmpty else {
            return worstTitle(states: states)
        }
        let title = NSMutableAttributedString()
        for (index, state) in states.enumerated() {
            if index > 0 {
                title.append(NSAttributedString(string: "  ", attributes: [.font: labelFont]))
            }
            title.append(NSAttributedString(
                string: state.profile.label,
                attributes: [.font: labelFont, .foregroundColor: NSColor.labelColor]
            ))
            title.append(symbol(for: state.status))
        }
        return title
    }

    private static func worstTitle(states: [ProfileState]) -> NSAttributedString {
        let aggregate = worstOf(states)
        let title = NSMutableAttributedString()
        title.append(symbol(for: aggregate.status, name: "circle.fill", pointSize: 8))
        if aggregate.degradedCount > 0 {
            title.append(NSAttributedString(
                string: " \(aggregate.degradedCount)",
                attributes: [.font: labelFont, .foregroundColor: NSColor.labelColor]
            ))
        }
        return title
    }

    private static func symbol(
        for status: ServiceStatus,
        name: String? = nil,
        pointSize: CGFloat = 10
    ) -> NSAttributedString {
        let symbolName = name ?? status.symbolName
        let configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .bold)
            .applying(.init(paletteColors: [color(for: status)]))
        guard
            let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbolName)?
                .withSymbolConfiguration(configuration)
        else {
            return NSAttributedString(string: "?", attributes: [.font: labelFont])
        }
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = CGRect(x: 0, y: -1.5, width: image.size.width, height: image.size.height)
        return NSAttributedString(attachment: attachment)
    }
}

extension ServiceStatus {
    /// Menu wording; the popover (Phase 2) will reuse it.
    var displayText: String {
        switch self {
        case .operational: return "Operational"
        case .maintenance: return "Under maintenance"
        case .unknown: return "Unreachable"
        case .minor: return "Minor incident"
        case .major: return "Major incident"
        case .critical: return "Critical incident"
        }
    }
}
