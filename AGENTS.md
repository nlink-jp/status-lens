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
    ServiceState.swift      ServiceStatus (severity-ordered), ProfileState,
                            worstOf() aggregation
    StatuspageClient.swift  SummaryFetching protocol, URLSession client,
                            loadStates() parallel never-throwing poll round
    Settings.swift          DisplayMode, Settings codec (forward-compatible
                            decodeIfPresent defaults), interval clamping
  status-lens/           Executable (AppKit)
    Entry.swift             @main; --version/--help dispatch vs GUI bootstrap
    AppDelegate.swift       NSStatusItem, polling timer, menu, App Nap activity
    StatusBarRenderer.swift NSAttributedString title (parallel/worst modes),
                            status→NSColor mapping
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

## Roadmap

- Phase 2: detail popover (components / incidents / maintenance),
  degradation & recovery notifications (rising-cross only), settings UI for
  profile CRUD, SMAppService login item
- Phase 3: app icon, signing + notarization, zip distribution, Homebrew tap,
  umbrella submodule + catalog integration
