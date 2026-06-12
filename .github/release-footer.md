
## Install

1. Download the `.zip` below and unzip it; move **Runtahio.app** to `/Applications` (optional).
2. Verify the download (optional): `shasum -a 256 -c Runtahio-*.zip.sha256`

> ### ⚠️ Gatekeeper: "Apple could not verify Runtahio…"
>
> This build is **ad-hoc signed and not notarized**, so macOS blocks it on first launch. To open it, do **one** of:
>
> - **Right-click** `Runtahio.app` → **Open** → **Open**, or
> - **System Settings → Privacy & Security** → **Open Anyway**, or
> - `xattr -dr com.apple.quarantine /path/to/Runtahio.app`
>
> Prefer to avoid this? Build from source: `./Scripts/make-app.sh --run`.

**Requirements:** macOS 26 or later, Apple Silicon (`arm64`).
