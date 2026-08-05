# Changelog

## Unreleased

### Added

- Statuspage API v2 client with open-set enum decoding (unknown indicator /
  component states degrade to `.unknown` instead of failing the summary)
- Profile model with built-in presets (Claude enabled by default, GitHub)
  and 2-character label suggestion
- Severity-ordered `ServiceStatus` with worst-of aggregation; unreachable
  pages surface over healthy states but never over real outages
- Menu bar rendering (plan C): per-profile "label + colored SF Symbols
  shape", or single worst-of indicator with degraded count
- 60-second polling loop (interval clamped 30–3600s) with App Nap
  countermeasure (`ProcessInfo.beginActivity`)
- Menu: per-profile status line (opens the status page), refresh now,
  display mode toggle, version line, quit
- `--version` / `--help` CLI surface (GUI-only binary otherwise)
- Repository scaffold per org conventions: Makefile (build → `dist/`),
  vendored codesign/notarize/brew scripts, RFP documents (ja/en)
