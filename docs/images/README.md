# Screenshots & media

Image assets referenced from the root `README.md` and the repo's social preview.

| File | Shows | Status |
| ---- | ----- | ------ |
| `runtah-map.png` | The radial **Runtah Map** sunburst | ✅ in README (Demo) |
| `treemap.png` | The squarified **treemap** view | ✅ in README (Screenshots) |
| `file-types.png` | The **File Types** analysis view | ✅ in README (Screenshots) |
| `social-preview.png` | 1280×640 repo social card | ✅ (upload via repo Settings) |
| `demo.gif` | ~15s demo: scan → drill → safe cleanup | ⏳ see [#2](https://github.com/cupskeee/runtahio/issues/2) |

## Demo GIF (`demo.gif`)

The README's **Demo** section is ready for a short (~15s) screen recording. Suggested
storyboard:

1. Open Runtahio.
2. Scan `~/Downloads` (⌘O).
3. The **Runtah Map** appears; hover a couple of segments.
4. Click a large folder — the file table syncs.
5. Add an item to the **Runtah Basket** (⌘⌫).
6. **Move to Trash** (⌘⇧⌫) and confirm.
7. Show the "Freed X" / Lapang Mode tally.

Record with [Kap](https://getkap.co) or QuickTime → `ffmpeg`/`gifski`; keep it short and
looped, ~1600px wide, and a few MB max. Save it as `docs/images/demo.gif`, then swap the
static image in the README's Demo section for it.

## Capture tips

- Run the real app: `./Scripts/make-app.sh --run`, then scan a folder with varied content
  (e.g. `~/Downloads`) so the map has interesting structure.
- Capture a single window (includes the rounded corners + shadow):
  ```bash
  screencapture -o -w docs/images/runtah-map.png   # then click the window
  ```
  Use `-o` to drop the drop-shadow if you prefer a tight crop.
- Prefer a Retina display so the PNGs are @2x and stay crisp on GitHub.
- Keep individual images reasonably small (resize to ~1600px wide / a few hundred KB) so
  the README loads quickly. For GIFs, [Kap](https://getkap.co) or QuickTime + `ffmpeg`
  work well; keep them short and looped.

## Social preview

**`social-preview.png`** (1280×640) is a ready-made repo card — the app icon, wordmark,
tagline, and feature pills on a dark brand background, with all content inside GitHub's
recommended 40px safe margin. Upload it under **Settings → General → Social preview**
(web UI only; there's no REST API for it).

It's generated from an HTML template rendered headlessly; to tweak it, re-render the card
at 1280×640 and re-export here.
