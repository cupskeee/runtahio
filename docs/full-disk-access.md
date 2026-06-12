# Full Disk Access — granting & troubleshooting

Runtahio reads filesystem **metadata only** and never needs special access to scan folders
**you own**. But to scan **system-protected locations** — other users' folders, parts of
`~/Library`, system volumes, the whole disk from `/` — macOS requires you to grant the app
**Full Disk Access (FDA)**.

> Runtahio still reads metadata only with FDA on — it never opens file contents and makes no
> network requests. FDA just lets macOS show it the protected directory listings.

## What works without Full Disk Access

Folders you own scan fine with no extra permission, e.g.:

- `~/Downloads`, `~/Documents`, `~/Desktop`, `~/Movies`, `~/Music`, `~/Pictures`
- Any external drive you can already open in Finder
- Most of your home folder

You only need FDA when a scan reports lots of **Inaccessible Items** in protected areas.

## Grant Full Disk Access

1. Launch the app via the `.app` bundle (`./Scripts/make-app.sh --run`, or the one you
   downloaded). **Don't** use a bare `swift run` binary — see the caveat below.
2. Open **System Settings → Privacy & Security → Full Disk Access**.
3. Click **+**, navigate to `Runtahio.app`, and add it (or drag it into the list).
4. Make sure its toggle is **on**.
5. **Quit and reopen Runtahio**, then rescan. FDA only takes effect after a relaunch.

## Troubleshooting

**"Runtahio isn't in the Full Disk Access list."**
Click **+** and navigate to wherever you put `Runtahio.app` (e.g. `/Applications` or the
repo folder), then add it. The app does not need to be running to be added.

**"I turned it on but scans still show inaccessible items."**
- **Quit and reopen** the app — the grant only applies to a fresh launch.
- Confirm the toggle is actually **on** (not just listed).
- Confirm you added the **same** `Runtahio.app` you're launching, not an older copy in a
  different folder.

**"It keeps forgetting the grant every time I rebuild."**
This is expected. Runtahio is **ad-hoc signed**, so each rebuild from source produces a new
identity that macOS treats as a different app. Fixes:
- Keep one stable copy (e.g. in `/Applications`) and always launch *that* one.
- Or grant FDA to the bundle `Scripts/make-app.sh` produces — it uses a fixed bundle id
  (`com.runtahio.app`), so re-granting after a rebuild reuses the same TCC entry far more
  reliably than a bare `swift run` binary (whose path changes every build).

**"A few items are still marked Inaccessible even with FDA on."**
Some paths are protected by System Integrity Protection or owned by other users and can't be
read by any app. Runtahio marks these as **Inaccessible Items** (see that analysis view)
rather than failing the whole scan — siblings keep scanning.

**"I'd rather not grant it at all."**
That's fine — just scan folders you own. You'll still get the full Runtah Map, treemap,
analysis views, and safe cleanup for everything you can already open in Finder.

## Why the `.app` bundle matters here

A bare `swift run` executable launches as a background process and its binary path changes
on every build, so macOS's FDA grant never sticks to it. `Scripts/make-app.sh` wraps the
binary into a `Runtahio.app` with a fixed bundle identifier and an ad-hoc signature, giving
it a stable identity that FDA can attach to. Always grant FDA to the bundle, not the raw
binary.
