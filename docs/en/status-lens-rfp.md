# RFP: status-lens

> Generated: 2026-08-06
> Status: Draft

## 1. Problem Statement

Outages of external SaaS services are usually noticed only when one's own work suddenly fails, wasting time on figuring out whether the cause is local or on the service side. status-lens is a macOS menu bar resident app that registers multiple Statuspage.io-hosted status pages (default: Claude) as profiles, continuously shows each service's operational status in the menu bar, and notifies on state changes.

The separation of concerns within nlink-jp's observability menu bar tools is clear: claude-usage-lens covers cost, load-spinner covers machine load, and status-lens covers service availability. Target user: nlink-jp (the developer themselves).

## 2. Functional Specification

### Commands / API Surface

- Menu bar resident GUI app. No CLI subcommands (GUI-only)
- As the sole exception, `status-lens --version` responds (required by Homebrew cask brew test)

### Input / Output

**Input**: Statuspage API v2 `/api/v2/summary.json` for each profile (no authentication). All enabled profiles are polled in parallel, default every 60 seconds (configurable).

**Menu bar display (Plan C: horizontal short label + status symbol)**:

- Each profile is rendered as "short label + status icon" side by side (e.g. `CL✓ GH✓ DB▲`)
- Status mapping (dual encoding of color + shape, using SF Symbols):

| State | Symbol | Color |
|-------|--------|-------|
| operational | checkmark | green |
| minor | exclamationmark.triangle | yellow |
| major | xmark | orange |
| critical | xmark | red |
| under maintenance | wrench | blue |
| API unreachable | questionmark | gray |

- Unreachable (network down, URL moved, etc.) is clearly distinguished from operational
- Display mode toggle: **parallel** (all profiles, as above) / **worst-of** (single indicator + count of degraded profiles, e.g. `●2`)

**Popover (opened on click)**:

- Hierarchy: profile → per-component status → active incidents (name, impact, latest update, timestamps) → scheduled maintenances
- Link to each profile's status page

**Notifications (macOS Notification Center)**:

- Notify on both degradation and recovery. Fire only on state-change crossings (no re-notification of the same state)
- Per-profile ON/OFF

### Configuration

- UserDefaults + settings UI (same approach as claude-usage-lens-gui / load-spinner, @AppStorage family)
- Profile definition: name / base URL / short label (2-3 chars, editable) / enabled flag / notification ON/OFF
- Built-in presets: Claude (status.claude.com, ON by default) and GitHub (www.githubstatus.com). Additional profiles can be registered from the settings UI with any Statuspage URL
- Polling interval (default 60s), display mode (parallel / worst-of)
- Launch at login (SMAppService, default OFF)

### External Dependencies

- Statuspage API v2 (public API of Atlassian Statuspage-hosted pages). No authentication or credentials

## 3. Design Decisions

- **Swift / AppKit NSStatusItem + SwiftUI panel (NSPopover)**: colored rendering cannot be done with template (monochrome) images, so MenuBarExtra is not used. Reuses the proven stack of load-spinner and claude-usage-lens-gui. darwin/arm64 only, macOS 13+
- **Designed as a generic Statuspage watcher**: not Claude-specific; the profile mechanism makes any Statuspage-hosted page a monitoring target. Claude is merely the default profile
- **Dual encoding with color + shape**: the state remains readable for color-vision deficiency and in shared screenshots. The vertical-label plate approach (load-spinner style) was prototyped and rejected due to height constraints and readability (see Discussion Log)
- **GUI-only (no CLI subcommands)**: an explicit exception to the org convention (GUI with embedded CLI). To be revisited if scripted status queries become a need
- **Naming**: status-lens, following the `-lens` series (claude-usage-lens / active-lens / sensor-lens). APP_NAME stays kebab-case per the load-spinner precedent (single GUI binary); Bundle ID jp.nlink.status-lens
- **Complements**: forms the observability menu bar GUI family together with claude-usage-lens (cost) and load-spinner (load)

**Out of scope**:

- Status page formats other than Statuspage (status.io, instatus, custom HTML, etc.)
- Uptime history accumulation and graphs
- Active health checks against arbitrary endpoints
- Cross-platform support (macOS only)

## 4. Development Plan

### Phase 1: Core

- Statuspage API client (fetch + strict decode of summary.json)
- Profile model + presets
- Pure functions for state aggregation, worst-of computation, label shortening + unit tests
- Menu bar display (Plan C; parallel / worst-of modes)
- Polling loop (including App Nap countermeasures)

### Phase 2: Features

- Popover details (component / incident / maintenance hierarchy)
- macOS notifications (degrade / recover, crossing-only)
- Settings UI (profile CRUD, interval, display mode, notification toggles)
- SMAppService login item

### Phase 3: Release

- App icon, README.md / README.ja.md, CHANGELOG.md, AGENTS.md
- Codesign + notarize + staple, GitHub Release, homebrew-tap cask
- util-series submodule integration, org profile / web catalog sync, check-org.sh

Each phase can be reviewed independently.

## 5. Required API Scopes / Permissions

None (public unauthenticated API only. On macOS, only the user consent for notifications)

## 6. Series Placement

Series: util-series
Reason: an observability menu bar resident GUI in the same family as claude-usage-lens-gui / load-spinner. A general-purpose utility — neither a client for a specific external service (cli-series) nor an experiment (lab-series).

## 7. External Platform Constraints

- Statuspage API v2 is unauthenticated and CDN-served; polling at 60s intervals is unproblematic
- **URLs can move**: status.anthropic.com has already moved to status.claude.com. Following HTTP redirects is mandatory; permanent redirects should surface in the popover so the user notices
- **Component composition changes without notice**: never hardcode component names/counts; render response-driven
- Overall indicator has 4 levels: none / minor / major / critical, plus maintenance. Component status is operational / degraded_performance / partial_outage / major_outage / under_maintenance
- Timestamps are UTC → convert to local TZ for display
- **App Nap**: an LSUIElement resident app gets its timers frozen by App Nap while no window is visible (learned in claude-usage-lens-gui v0.1.7). Hold `ProcessInfo.beginActivity` for the app's lifetime

---

## Discussion Log

- 2026-08-06: Originated from the separation-of-concerns idea "cost = claude-usage-lens, service status = this tool". Confirmed by live API probing that status.anthropic.com has moved to status.claude.com
- **Dedicated vs generic**: since the Statuspage API schema is identical across all hosted pages, decided on generic + profile selection rather than Claude-specific
- **Tool name**: status-lens, following the -lens series naming (service-lens / statuspage-lens rejected)
- **Monitoring model**: multiple profiles watched simultaneously, with a display mode toggle between parallel and worst-of. The concern "it becomes incomprehensible without labels" drove a focused study of representations
- **Menu bar representation history**: (1) compared horizontal plans A (label + colored dot) / B (colored label) / C (label + shape symbol) / D (collapse when all healthy) → (2) considered load-spinner-style vertical plates (V1 colored plate / V2 colored text) to save width → (3) prototyped V1+C combinations (symbol embedded in plate → upright icon beside plate) → (4) finally **adopted horizontal Plan C (label + shape symbol, with color)**. Vertical layouts were rejected due to the 22pt menu bar height constraint and readability
- **Notifications**: both degradation and recovery (fire only on worsening crossings, per-profile toggle)
- **CLI cohabitation**: GUI-only, responding only to --version; recorded as an explicit exception to the org convention
- **Config storage**: UserDefaults + settings UI (a TOML file was rejected as it would duplicate state management with the GUI)
