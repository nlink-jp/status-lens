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
- `make verify-release` — gate: `.notarized` marker + `stapler validate` (run before upload).
- `make brew` — generate the Homebrew cask from the built zip into the local
  `nlink-jp/homebrew-tap` checkout (see `scripts/release-brew.mk`).
- `make test` / `swift test` — runs `StatusLensCoreTests` (55 tests).
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
    ComponentDigest.swift   componentDigest() — popover collapse rule for
                            large pages (Cloudflare has hundreds of PoP
                            components; >12 → noteworthy-only + counts)
    StatuspageClient.swift  SummaryFetching protocol, URLSession client,
                            loadStates() parallel never-throwing poll round
    Settings.swift          DisplayMode, Settings codec (forward-compatible
                            decodeIfPresent defaults), interval clamping
    PanelToggle.swift       one click, two events (global monitor + button
                            action): who dismisses, who opens, and what the
                            popover's own readings cannot tell (pure)
    SingleInstance.swift    singleInstanceDecision() — startup duplicate-
                            instance guard (pure; pids in, decision out)
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

- **The release build pins the linked SDK.** macOS decides which generation of
  window chrome to draw from `LC_BUILD_VERSION`'s sdk field, and the Xcode 27 /
  Swift 6.4 `swift build` stamps it with the deployment target, not the SDK it
  compiled against — an app shipped that way draws with the previous design
  (square window corners). `make build` passes `-platform_version macos
  $(MACOS_MIN) $(MACOS_SDK)` (the minimum read from Package.swift, so it is
  stated once), and `make verify-release` fails if the built bundle's sdk is not
  the current one. Signing, notarization and every test pass either way, so the
  gate is the only thing that can catch it.
- **Colored menu bar content needs AppKit, not `MenuBarExtra`.** Template
  images are monochrome; the plan-C rendering is an `NSStatusItem` attributed
  title mixing label text runs with tinted SF Symbols `NSTextAttachment`s
  (`NSImage.SymbolConfiguration(paletteColors:)`).
- **Open-set enum decoding is deliberate.** Statuspage adds components and
  states without notice; component composition must never be hardcoded and
  unknown raw values map to `.unknown` (rendered as gray `?`).
- **Statuspage-compatible ≠ Atlassian Statuspage.** Some catalog pages run
  compatible re-implementations (OpenAI: ULID ids, no top-level
  `scheduled_maintenances`). Top-level arrays decode with empty defaults
  and `page.url` is optional. When probing catalog candidates, hit
  `summary.json` (what the app actually fetches) — `status.json` alone
  passed OpenAI while `summary.json` did not.
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
- **Notification clicks launch by bundle ID — enforce a single instance.**
  Clicking a banner makes notificationd open the app via LaunchServices,
  which resolves `jp.nlink.status-lens` among *all* registered copies
  (`dist/` dev builds, release-verification extractions, `/Applications`)
  and may start a different copy than the running one → two menu bar
  items, double polling (observed 2026-08-25). Guarded at two layers:
  `LSMultipleInstancesProhibited` (Info.plist, stops LaunchServices
  launches) and a startup check in `Entry.main`
  (`singleInstanceDecision`, core-tested) that exits with a stderr note
  (covers direct exec / `open -n`). Side effect: to run a `dist/` build,
  quit the installed instance first — a second copy now refuses to start.
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
- **The popover must take key focus on open, or it renders dimmed.** A
  status item click does not activate an accessory app, so the popover
  window opens non-key and macOS draws its material in the inactive state —
  under macOS 26's Liquid Glass that is a visibly dark, dimmed sheet.
  `togglePopover` calls `makeKey()` on the popover window right after
  `show(relativeTo:)` (measured 2026-08-15: +32/255 mean luminance in the
  panel body; `makeKey()` alone is pixel-identical to `NSApp.activate` +
  `makeKey()`). Same line as load-spinner's panel.
  - **`makeKey()` is not an activation.** This entry used to end "and
    `makeKey()` activates the app as a side effect anyway". That was an
    inference from the identical pixels; the activation state had never been
    measured. Measured on the installed v0.1.3 (macOS 27.0, 2026-09-20):
    after the status item click + `makeKey()`, status-lens was never the
    frontmost app — 3/3, `NSWorkspace.frontmostApplication` and
    `lsappinfo front` agreed, sampled from 0.15 s to 3 s after opening.
  - Opening the popover takes frontmost status away, if anything: with
    status-lens frontmost beforehand (settings window opened through
    "Settings…", which calls `NSApp.activate`), the previously frontmost app
    was frontmost again 0.15 s after the status item click — 3/3, and 3/3 on
    a control build without `makeKey()`. "The app is active while its popover
    is open" is not a state the status item click produces.
- **A click on the status item is decided by `PanelToggle` (`StatusLensCore`), and
  nothing reads the panel to do it.** Measured on the real app (macOS 27.0,
  2026-09-21) with synthetic HID clicks and every event logged:
  - **`NSPopover.isShown` stays true for about half a second after a close**,
    until `popoverDidClose` — and that report arrives *after* a show that
    followed it, so the delegate callback cannot be believed on its own either.
    The panel window's `isVisible` goes false at once, but it is also false
    between a show and the moment the panel appears (AppKit queues a show that
    starts during a close animation behind it, about 0.4 s). **This was the
    reported defect**: deciding from `isShown`, a re-click inside that half
    second was read as "the panel is open" and closed it again, so the panel did
    not open — 0 out of 10 at every gap tried on the release build, against 10
    out of 10 at 130 ms and 200 ms with the fix.
  - **The panel can only be opened from the button's action.** A show issued
    from the monitor, on the mouse-down or on the mouse-up, was dismissed by
    AppKit inside the same click, every time. The monitor's part is to dismiss.
  - **One click produces two events and the second often does not come**: the
    monitor sees it first, the action 23–41 ms later, and of eight
    well-separated clicks eight were monitored and five produced an action (the
    missing ones being clicks that closed the panel). So an action within
    `PanelToggle.actionWindow` (0.1 s) of the monitor closing the panel for a
    click on the item is that click's second event and does nothing. **Do not
    pair the two events by order** — with one of them missing, "the action of
    the click that just closed the panel" and "the action of the click that is
    meant to open it" are the same event; an earlier fix did pair them and
    swallowed clicks.
  - **Residual, measured:** at a 60–100 ms gap the panel ended up closed once in
    ten, when the dismissed click's action arrived after the window and was
    taken for a click of its own. Two clicks that fast are one gesture, and the
    alternative — a longer window — swallows the re-click, which is the defect
    above. Pinned by `testAVeryFastDoubleClickCanEndUpClosed`.
  - The rule that nothing decides from `isShown` is machine-checked by
    `PanelReadingRuleTests`; the AppKit readings above are pinned by
    `PopoverReadingsTests`.
- **Outside-click dismissal never relies on `.transient`.** The global + local
  mouse-down monitors are installed at launch (`installPopoverClickMonitors`)
  and kept for as long as the app runs; the local monitor must ignore the status
  item button's window or a button click would close-then-reopen. What is
  known about why, and where each part comes from:
  - **Observed 2026-08-06 (v0.1.1):** after the settings window +
    `NSApp.activate` was added, the popover stopped closing on outside
    clicks, and the monitors went in. That build had no `makeKey()` yet
    (v0.1.2 added it). The observation stands. What this entry made of it —
    "`.transient` breaks once the app has been activated, by the settings
    window or by the popover's own `makeKey()`" — was a causal reading, and
    the measurements below do not support either half.
  - **Measured 2026-09-20 (macOS 27.0)** on control builds of the current
    source, run as bare release binaries, 3 clicks per cell. With only the
    `installPopoverClickMonitors()` call removed, `.transient` closed the
    popover when the outside click landed in a window that takes activation
    (another app's normal window 3/3, the already-frontmost app's window
    3/3) and missed surfaces that take none (another process's
    non-activating panel 0/3, an empty stretch of the menu bar 0/3). The
    same numbers came back in all three states tried: never activated;
    settings window open and status-lens made frontmost before every trial
    (the already-frontmost case was not run there); settings opened, then
    closed. Activation history changed nothing.
  - **With `makeKey()` removed as well** (the 2026-08-06 shape), nothing
    closed: 0/3 on all four surfaces, including the clicks that made another
    app frontmost. On this app `makeKey()` is what lets `.transient` work at
    all, not what breaks it — and the monitors are needed either way.
    load-spinner's `makeKey()`-less control still closed on activation-taking
    clicks, so this detail does not carry across apps without measuring.
  - **The shipped combination** (installed v0.1.3, same day): every outside
    surface closed 3/3 in the same three states; in the never-activated
    state an inside click kept it open 3/3 and a status item click closed it
    without reopening 3/3.
  - Method, and the rules for re-verifying (synthetic HID clicks, status item
    frame from the AX `AXExtrasMenuBar`, popover visibility from
    `CGWindowList`, click only a probe-owned window/panel or a point just
    re-read as `AXMenuBar`): load-spinner's AGENTS.md, "Outside-click
    dismissal never relies on `.transient` alone". Not measured here: a click
    into status-lens's own settings window with the monitors removed.
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
