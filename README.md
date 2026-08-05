# status-lens

[日本語版 README](README.ja.md)

Menu bar service status watcher for Statuspage-hosted pages.

status-lens sits in the macOS menu bar and continuously shows the operational
status of the services you depend on — Claude, GitHub, or any other page hosted
on Atlassian Statuspage — so you notice an outage before your own work fails
mysteriously. Within the nlink-jp observability family, claude-usage-lens
watches cost, load-spinner watches machine load, and status-lens watches
service availability.

## Menu bar display

Each watched profile renders as a short label plus a colored shape symbol
(dual-encoded, so the state survives grayscale and color-vision deficiency):

| State | Symbol | Color |
|-------|--------|-------|
| Operational | checkmark | green |
| Minor incident | warning triangle | yellow |
| Major incident | x mark | orange |
| Critical incident | x mark | red |
| Under maintenance | wrench | blue |
| Unreachable | question mark | gray |

Two display modes, switchable from the menu:

- **Show every profile** — one label + symbol per profile (e.g. `CL✓ GH✓`)
- **Show worst status only** — a single colored dot, plus the number of
  degraded profiles when any

"Unreachable" (network down, page URL moved) is deliberately distinct from
"operational": when the watcher is blind, it says so.

## Profiles

A profile is one Statuspage-hosted status page: a name, its base URL, and a
1–3 character menu bar label. Built-in presets:

- **Claude** (`status.claude.com`) — enabled by default
- **GitHub** (`www.githubstatus.com`)

Any Statuspage-hosted page can be added (settings UI planned; see status
below). Polling hits the public unauthenticated API
(`/api/v2/summary.json`) every 60 seconds by default.

## Usage

Launch the app; the indicator appears in the menu bar.

**Left click** opens the detail popover: per profile, the component grid
(severity dots), active incidents (impact color, latest update, relative
time), and scheduled maintenance, plus refresh / settings / quit in the
footer.

**Right click** opens the quick menu: per-profile status line (opens the
status page), refresh now, display mode toggle, settings, quit.

**Notifications** fire on worsening crossings (operational → incident, or
minor → major) and on recovery — never repeatedly for an unchanged state.
Per-profile bell toggle in settings.

**Settings** (gear in the popover, or right-click menu): profile CRUD
(name / URL / menu bar label / watch / notify), polling interval, display
mode, launch at login. Changes apply immediately, the Mac way — text
fields commit on Enter or focus loss; an invalid URL is flagged inline
while the previous address stays in effect.

The binary is GUI-only and responds to exactly two flags:

```bash
status-lens --version
```

```bash
status-lens --help
```

## Development status

Phase 1 (core + menu bar) and Phase 2 (popover, notifications, settings,
launch at login) are implemented. Planned next:

- Phase 3: app icon, signed + notarized release, Homebrew tap

Note: notifications and launch-at-login require the `.app` bundle; the
bare dev binary degrades gracefully (stderr log / disabled toggle).

## Build from source

Requires macOS 13+ (darwin/arm64) and a Swift 6 toolchain.

```bash
make build
```

```bash
make test
```

`make build-app` assembles `dist/status-lens.app` (Developer ID signing);
`make package` notarizes, staples, and zips it for release.

## Design notes

Design decisions and their history are recorded in the RFP:
[docs/en/status-lens-rfp.md](docs/en/status-lens-rfp.md).

## License

MIT — see [LICENSE](LICENSE).
