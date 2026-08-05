# AGENTS.md — status-lens

## Summary

macOS menu bar app (util-series) watching the operational status of
Statuspage-hosted status pages (Claude by default; GitHub and any other
Statuspage URL as profiles). Each profile renders as a short label + colored
SF Symbols shape (plan C: color + shape dual encoding); a worst-of mode
collapses everything into one dot + degraded count. Swift/AppKit + SwiftUI,
darwin/arm64, macOS 13+. GUI-only binary: responds to `--version`/`--help`,
no other CLI subcommands (explicit org-convention exception, see RFP).

## Build & test

- `make build` — compiles the release binary. **Never** run `swift build -c release`
  directly for release output; always use the Makefile.
- `make build-app` — assembles `dist/status-lens.app` (Info.plist version from
  `git describe`) and signs it with a Developer ID Application identity.
- `make package` — build-app, then notarize + staple (`nlink-jp-notary`
  keychain profile), and zip to `dist/status-lens-<version>-darwin-arm64.zip`.
- `make brew` — generate the Homebrew cask from the built zip into the local
  `nlink-jp/homebrew-tap` checkout (see `scripts/release-brew.mk`).
- `make test` / `swift test` — runs `StatusLensCoreTests` (25 tests).
- `make run` — `swift run` (debug).

Signing/notarization uses the shared scripts under `scripts/` (vendored from
the org `.github` templates), same as the other util-series GUI apps.

## Structure

```
Sources/
  StatusLensCore/        Pure, testable logic (no AppKit UI)
    StatuspageModels.swift  summary.json Codable models; StatusIndicator /
                            ComponentStatus are open sets (unknown raw values
                            decode to .unknown, never fail the summary)
    Profile.swift           Profile (+presets Claude/GitHub), label suggestion
    ServiceCatalog.swift    Built-in "Add profile" directory (17 services,
                            every URL probed live against the Statuspage API
                            on 2026-08-06 — verify before adding entries)
    ServiceState.swift      ServiceStatus (severity-ordered), ProfileState,
                            worstOf() aggregation
    StatuspageClient.swift  SummaryFetching protocol, URLSession client,
                            loadStates() parallel never-throwing poll round
    Settings.swift          DisplayMode, Settings codec (forward-compatible
                            decodeIfPresent defaults), interval clamping
  status-lens/           Executable (AppKit + SwiftUI)
    Entry.swift             @main; --version/--help dispatch vs GUI bootstrap
    AppDelegate.swift       NSStatusItem (left=popover / right=quick menu),
                            polling timer, transition notifications, settings
                            window, App Nap activity
    AppModel.swift          ObservableObject snapshot for SwiftUI views;
                            AppActions closures; Settings typealias
    StatusBarRenderer.swift NSAttributedString title (parallel/worst modes),
                            status→NSColor mapping
    PopoverView.swift       Detail popover (components/incidents/maintenance)
    SettingsView.swift      Draft-based settings form (validated Apply)
    Notifier.swift          UNUserNotificationCenter wrapper (bundle-gated)
    LoginItem.swift         SMAppService wrapper (bundle-gated)
    MainMenu.swift          Main menu for Edit/Close key equivalents
    SettingsStore.swift     UserDefaults persistence (codec lives in core)
    Version.swift           appVersion from bundle Info.plist ("dev" fallback)
Tests/StatusLensCoreTests/
docs/{en,ja}/            RFP (design decisions + discussion log)
```

## Design notes / gotchas

- **Colored menu bar content needs AppKit, not `MenuBarExtra`.** Template
  images are monochrome; the plan-C rendering is an `NSStatusItem` attributed
  title mixing label text runs with tinted SF Symbols `NSTextAttachment`s
  (`NSImage.SymbolConfiguration(paletteColors:)`).
- **Open-set enum decoding is deliberate.** Statuspage adds components and
  states without notice; component composition must never be hardcoded and
  unknown raw values map to `.unknown` (rendered as gray `?`).
- **Unreachable ranks between healthy and degraded.** Severity order is
  operational < maintenance < unknown < minor < major < critical: a blind
  watcher must be visible, but must not outrank a real outage.
- **Page URLs move.** status.anthropic.com → status.claude.com is a live
  precedent; the URLSession client follows redirects.
- **App Nap.** LSUIElement apps freeze their timers when napped;
  `ProcessInfo.beginActivity(.userInitiatedAllowingIdleSystemSleep)` is held
  for the app lifetime (lesson from claude-usage-lens-gui v0.1.7).
- **Swift 6 strict concurrency.** UI types are `@MainActor`; the poll timer
  uses the target/selector API; `SummaryFetching` and all core types are
  `Sendable`. Test stubs must not capture XCTestCase `self` in `@Sendable`
  closures (use static helpers).
- **Testability.** All non-trivial logic lives in `StatusLensCore` behind the
  `SummaryFetching` protocol; the AppKit layer stays thin. `loadStates` never
  throws — failures degrade to per-profile `.unknown` states.
- **`Settings` name collision.** SwiftUI exports a `Settings` scene; the app
  module pins `typealias Settings = StatusLensCore.Settings` (AppModel.swift).
- **Bundle-gated system services.** `UNUserNotificationCenter` and
  `SMAppService` crash / fail without a real bundle. Both are gated on
  `Bundle.main.bundleIdentifier != nil`: the bare dev binary logs
  notifications to stderr and disables the login-item toggle.
- **Notifications fire on crossings only.** `statusTransition()` (core,
  tested) gates: worsening into/within degraded fires, improvements within
  degraded stay silent, leaving degraded fires recovery. First observation
  is the baseline, never a notification.
- **Popover content is built lazily** (created on open, released in
  `popoverDidClose`) so no SwiftUI tree lays out while hidden — same lesson
  as load-spinner's panel.
- **Every borderless icon button in the popover needs `.focusable(false)`.**
  Otherwise the first focusable control grabs keyboard focus the instant the
  popover opens and draws a focus ring (same lesson as load-spinner's flip
  toggles).
- **An LSUIElement app still needs a main menu** for ⌘C/⌘V/⌘A in the
  settings window's text fields and ⌘W to close it (`MainMenu.swift`).
- **Settings apply immediately** (v0.1.1; the Apply-button draft model was
  rejected as un-Mac-like). Toggles/pickers write through on change; URL,
  label, and interval fields commit on Enter / focus loss (`@FocusState`
  onChange). The URL field validates at commit (`Profile.parseBaseURL`) —
  invalid input is flagged inline and the previous valid URL stays in
  effect, so half-typed URLs still never reach the polling loop.
  `AppDelegate.apply` is called on every edit: it rebinds cached states so
  name/label edits render instantly, and refetches only when the polling
  set (enabled × URL) actually changed. In-flight polls are cancelled and
  their results rebound against current settings before use.
  Launch-at-login reads and writes SMAppService directly — system state,
  deliberately not persisted in `Settings`.

## Roadmap

- Phase 3: app icon, signing + notarization, zip distribution, Homebrew tap,
  umbrella submodule + catalog integration
