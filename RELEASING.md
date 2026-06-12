# Releasing Runtahio

Releases are automated by [`.github/workflows/release.yml`](.github/workflows/release.yml):
pushing a `vX.Y.Z` tag builds the signed `.app`, zips + checksums it, and publishes a
GitHub Release whose notes are the matching `CHANGELOG.md` section plus the install /
Gatekeeper footer ([`.github/release-footer.md`](.github/release-footer.md)).

## Cutting a release

1. **Update the changelog.** In `CHANGELOG.md`, move the items under `## [Unreleased]`
   into a new `## [X.Y.Z] - YYYY-MM-DD` section, and add the `[X.Y.Z]` link reference at
   the bottom. Leave a fresh, empty `## [Unreleased]`.
2. **Commit** on `main`:
   ```bash
   git add CHANGELOG.md
   git commit -m "Release vX.Y.Z"
   git push origin main
   ```
3. **Tag and push the tag** (this triggers the Release workflow):
   ```bash
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
4. Watch it: `gh run watch` or the **Actions → Release** tab. When it's green, the
   release is live at `https://github.com/cupskeee/runtahio/releases/tag/vX.Y.Z` with the
   `Runtahio-vX.Y.Z-macOS-arm64.zip` asset and its `.sha256`.

## How versions are stamped

`Scripts/make-app.sh` derives the app's version from git:

- `CFBundleShortVersionString` ← the nearest tag (e.g. `v0.2.0` → `0.2.0`)
- `CFBundleVersion` ← the total commit count (a monotonic build number)

It falls back to `0.0.0` / `1` outside a git checkout.

> **Local-build gotcha:** if you created the tag via the GitHub UI / `gh release create`,
> it exists only on the remote. Run `git fetch --tags` before building locally, or
> `git describe` won't see it and the bundle will be stamped `0.0.0`. The CI runners check
> out with full history (`fetch-depth: 0`), so the automated release is unaffected.

## Building a release artifact by hand (fallback)

If you ever need to package without the workflow:

```bash
git fetch --tags
./Scripts/make-app.sh
ZIP="Runtahio-vX.Y.Z-macOS-arm64.zip"
ditto -c -k --sequesterRsrc --keepParent Runtahio.app "$ZIP"
shasum -a 256 "$ZIP" > "$ZIP.sha256"
gh release create vX.Y.Z --title "Runtahio vX.Y.Z" \
  --notes-file <(cat <(sed -n '/## \[X.Y.Z\]/,/## \[/p' CHANGELOG.md) .github/release-footer.md) \
  "$ZIP" "$ZIP.sha256"
```

## Notes

- Builds are **ad-hoc signed, not notarized** — the release notes tell users how to get
  past Gatekeeper. Proper Developer ID signing + notarization (needs a paid Apple
  Developer account) would remove that step and is the prerequisite for a Homebrew Cask.
- The artifact is **Apple Silicon (`arm64`)** only, matching the macOS 26 target.
