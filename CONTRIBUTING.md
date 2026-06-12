# Contributing to Runtahio

Thanks for your interest in improving Runtahio! This is a native macOS disk-usage
visualizer and **safe, Trash-only** cleanup utility. Contributions of all kinds are
welcome — bug reports, fixes, features, docs, and localizations.

By participating you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## Project principles (please preserve these)

Runtahio has a few invariants that contributions must not break. They're enforced by
tests and reviewed on every PR:

1. **Local-only.** No network requests, telemetry, or analytics — ever. A unit test
   guards against any `http(s)` URLs in the codebase.
2. **Metadata only.** The scanner reads `URLResourceValues` and never opens or reads
   file contents, and never materializes cloud (dataless) files.
3. **Trash-only cleanup.** Removal goes through `FileManager.trashItem(...)`. There is
   no permanent-delete path, and protected/system paths can't be added to the basket.
4. **Swift 6 strict concurrency.** The code builds clean under `swiftLanguageMode(.v6)`.
   The scanned `DiskNode` tree is immutable/`Sendable`; don't introduce shared mutable state.

## Requirements

- macOS 26 or later (Apple Silicon).
- Xcode 26 / Swift 6.2 toolchain.
- No third-party dependencies — please keep it that way unless there's a strong reason.

## Getting started

```bash
# Clone your fork
git clone https://github.com/<your-username>/runtahio.git
cd runtahio

# Run the headless test suite
swift test

# Build & launch the real .app bundle (recommended for UI/behavior work)
./Scripts/make-app.sh --run
```

See the [README](README.md#build--run) for why the `.app` bundle (not `swift run`) is
the right way to actually run the app.

## Project layout

- `Sources/RuntahioCore/` — pure, testable logic (no SwiftUI, no `@main`). **Put new
  business logic here** so it can be unit-tested.
- `Sources/Runtahio/` — the SwiftUI app, views, and AppKit/QuickLook interop.
- `Tests/RuntahioCoreTests/` — XCTest cases over the Core library.
- `Scripts/` — `make-app.sh` (bundle builder) and `generate-icon.swift` (icon renderer).

## Making a change

1. **Open an issue first** for anything non-trivial, so we can agree on the approach.
2. Create a branch off `main`: `git checkout -b fix/short-description`.
3. Add or update tests in `RuntahioCoreTests` for any logic change.
4. Make sure `swift test` passes and the app builds without concurrency warnings.
5. Update `CHANGELOG.md` under the **Unreleased** heading for user-facing changes.
6. Open a pull request using the template; link the related issue.

## Coding style

- Match the surrounding code: clear names, focused types, doc comments on public API.
- Keep `RuntahioCore` free of SwiftUI/AppKit imports.
- Prefer pure functions and value types; keep `@MainActor` boundaries explicit.
- Formatting follows the repo's [`.swift-format`](.swift-format) config (4-space indent,
  100-column). Run `swift format --in-place --recursive Sources Tests` before committing.
  CI **enforces** this with `swift format lint --strict`, so an unformatted PR fails the
  **Lint** check.

## Commit messages

Use clear, imperative subject lines (e.g. "Add CSV export for analysis views"). A short
body explaining the *why* is appreciated for non-obvious changes.

## Releasing

Maintainers: see [RELEASING.md](RELEASING.md). In short — update `CHANGELOG.md`, then push
a `vX.Y.Z` tag; the Release workflow builds the signed `.app`, checksums it, and publishes
the GitHub Release automatically.

## Reporting bugs & requesting features

Use the [issue templates](https://github.com/cupskeee/runtahio/issues/new/choose). For
security issues, **do not** open a public issue — see [SECURITY.md](SECURITY.md).
