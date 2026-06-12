# CLAUDE.md

Quick operational guide for AI agents (Claude Code) working in this repo. For depth, see
[README.md](README.md) (features/architecture), [CONTRIBUTING.md](CONTRIBUTING.md)
(workflow), and [RELEASING.md](RELEASING.md) (releases).

## What this is

**Runtahio** — a native macOS (SwiftUI + AppKit, Swift 6.2) disk-usage visualizer and
**safe, Trash-only** cleanup utility. Single Swift Package: `RuntahioCore` (pure logic) +
`Runtahio` (the app) + `RuntahioCoreTests`.

## Requirements

macOS 26+, Apple Silicon · Xcode 26 / Swift 6.2 · no third-party dependencies.

## Commands

```bash
swift test                                            # headless suite (~85 XCTest cases)
./Scripts/make-app.sh --run                           # build + launch the real .app
./Scripts/make-app.sh [--debug] [--no-sign] [--run]   # build the signed bundle
swift format --in-place --recursive Sources Tests     # format BEFORE committing (CI-enforced)
swift format lint --strict --recursive Sources Tests  # what CI checks
```

> Run via the `.app` bundle, **not** `swift run`: a bare binary launches background-only
> (no menu bar) and its changing path means Full Disk Access never sticks. `make-app.sh`
> wraps a signed bundle with a stable id (`com.runtahio.app`).

## Project invariants — do NOT break (each is guarded by a test)

1. **Local-only** — no network, telemetry, or analytics. A test rejects any `http(s)` URL in
   the codebase.
2. **Metadata-only** — the scanner reads `URLResourceValues`; it never opens file contents
   or materializes cloud (dataless) files.
3. **Trash-only cleanup** — `FileManager.trashItem(...)`, no permanent delete. Protected /
   system paths can't be staged (`ProtectedPathPolicy`).
4. **Swift 6 strict concurrency** — builds clean under `swiftLanguageMode(.v6)`. The
   `DiskNode` tree is immutable/`Sendable`; don't introduce shared mutable state.

## Layout

- `Sources/RuntahioCore/` — pure, testable logic (no SwiftUI, no `@main`). **Put new logic here.**
- `Sources/Runtahio/` — SwiftUI app, views, AppKit/QuickLook interop.
- `Tests/RuntahioCoreTests/` — XCTest over the Core library.
- `Scripts/` — `make-app.sh` (bundle builder, stamps version from the git tag), `generate-icon.swift`.

## CI, formatting, releases

- **CI** (`.github/workflows/ci.yml`): `Build & Test` + a strict `Lint` job — **both are
  required** on `main` (branch protection). Format before pushing or `Lint` fails.
- **Style**: [`.swift-format`](.swift-format) — 4-space indent, 100 columns.
- **Releases**: push a `vX.Y.Z` tag → `release.yml` builds/signs/zips/publishes (see
  RELEASING.md). `make-app.sh` derives the version from the nearest tag — run
  `git fetch --tags` before a local release build or it stamps `0.0.0`.

## Conventions

- **Commit messages: do NOT append a `Co-Authored-By: Claude` trailer** — the repo owner had
  it stripped from history and wants it kept out.
