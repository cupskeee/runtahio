# Changelog

All notable changes to Runtahio are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_Nothing yet._

## [0.1.0] - 2026-06-12

Initial public release (MVP).

### Added

- **Scanner** — off-main `actor` that recursively scans a folder or volume reading
  filesystem **metadata only**, emitting an ordered `AsyncStream<ScanEvent>`. Doesn't
  follow symlinks; excludes `.nofollow` by default to avoid double-counting the filesystem.
- **Runtah Map** — original radial "bloom" sunburst visualization (angle proportional to
  size, colored by file type, tiny items collapsed into "Other") with hover/select/drill.
- **Treemap** — squarified treemap view, switchable per scan, with animated zoom
  transitions on drill in/out.
- **File table** — sortable, searchable (Name / Size / Kind / Modified / Path), folders-first.
- **Inspector** — full per-item details including logical & allocated size, dates, flags,
  child counts, and scan errors.
- **Runtah Basket** — stage items and **Move to Trash** (Trash-only, never permanent)
  behind a confirmation dialog, with overlap-safe dedup totals.
- **Protected-path policy** — blocks the disk root, system domains, volume mount roots,
  and the Home folder from being staged for removal.
- **Analysis views** — Largest Files, Old Files, File Types breakdown, Duplicates, and
  Inaccessible Items.
- **Export** — scan report as JSON or CSV (local only).
- **Lapang Mode** — session tally of reclaimed space.
- **Volumes** — scan internal and external volumes from the sidebar, with eject for
  removable drives and live mount/unmount refresh.
- **Localization** — English and Bahasa Indonesia, with playful Sundanese status microcopy.
- **Onboarding** — first-run screen and an original app icon.
- **Privacy** — fully local; no network, telemetry, or analytics (guarded by a unit test).
- **Tooling** — `Scripts/make-app.sh` to wrap the binary into an ad-hoc-signed
  `Runtahio.app` with a stable bundle identity for Full Disk Access.
- **Tests** — 84 headless XCTest cases over `RuntahioCore`.

[Unreleased]: https://github.com/cupskeee/runtahio/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/cupskeee/runtahio/releases/tag/v0.1.0
