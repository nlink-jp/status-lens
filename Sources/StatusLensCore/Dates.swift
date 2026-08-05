import Foundation

/// Parse a Statuspage timestamp. The API mixes fractional
/// ("2026-08-05T14:44:00.887Z") and whole-second forms.
public func parseStatuspageDate(_ string: String?) -> Date? {
    guard let string else { return nil }
    if let date = fractionalFormatter.date(from: string) { return date }
    return plainFormatter.date(from: string)
}

// ISO8601DateFormatter is documented thread-safe; it just predates Sendable.
nonisolated(unsafe) private let fractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

nonisolated(unsafe) private let plainFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
}()
