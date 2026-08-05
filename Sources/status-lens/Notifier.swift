import Foundation
import UserNotifications

/// macOS Notification Center wrapper. UNUserNotificationCenter requires a
/// real app bundle — running the bare binary (swift run, .build/release)
/// would crash on first access, so everything is gated on a bundle identifier
/// and degrades to a stderr line during development.
@MainActor
final class Notifier {
    private let available = Bundle.main.bundleIdentifier != nil

    func requestAuthorizationIfAvailable() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func notify(title: String, body: String) {
        guard available else {
            FileHandle.standardError.write(
                Data("status-lens: notification suppressed outside app bundle: \(title)\n".utf8)
            )
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        if !body.isEmpty { content.body = body }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
