# CLAUDE.md — status-lens

**Organization rules (mandatory): https://github.com/nlink-jp/.github/blob/main/CONVENTIONS.md**

## Project rules

- **Tests are mandatory** — every core behavior change comes with tests in
  `Tests/StatusLensCoreTests/`. UI stays thin; logic goes in `StatusLensCore`.
- **`make build`, never bare release builds** — output belongs under `dist/`.
- **Docs in sync** — README.md and README.ja.md change in the same commit as
  behavior; CHANGELOG.md gets an entry under the correct version.
- **Small, typed commits** — `feat:`, `fix:`, `docs:`, `test:`, `chore:`.
- **Open-set decoding** — never hardcode Statuspage component names or add a
  closed enum for platform-controlled values; unknown raw values must decode
  to `.unknown`, not fail.
- **No secrets** — signing identity and notary credentials live in the
  keychain, never in the tree. `CODESIGN_IDENTITY` / `NOTARY_PROFILE` keep
  their generic defaults.

Design decisions and their history: `docs/ja/status-lens-rfp.ja.md` (primary)
/ `docs/en/status-lens-rfp.md`.
