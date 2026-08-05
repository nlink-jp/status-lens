import Foundation

/// The application version, injected into the bundle's Info.plist by `make build-app`.
///
/// Falls back to "dev" when run outside the bundle (e.g. `swift run`).
var appVersion: String {
    (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "dev"
}
