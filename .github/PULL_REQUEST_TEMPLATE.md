<!-- Thanks for contributing to Runtahio! Please fill out the sections below. -->

## Summary

<!-- What does this PR do, and why? -->

## Related issues

<!-- e.g. Closes #123 -->

## Changes

<!-- A short bullet list of the notable changes. -->
-

## Testing

<!-- How did you verify this? -->
- [ ] `swift test` passes locally
- [ ] Built and ran the app via `./Scripts/make-app.sh --run` (for UI/behavior changes)

## Checklist

- [ ] Code is Swift 6 strict-concurrency clean (builds without concurrency warnings)
- [ ] New/changed logic in `RuntahioCore` is covered by tests in `Tests/RuntahioCoreTests`
- [ ] No network calls, telemetry, or analytics were introduced (Runtahio is local-only)
- [ ] Cleanup remains Trash-only; no permanent deletion paths were added
- [ ] Updated `CHANGELOG.md` under "Unreleased" if this is a user-facing change
