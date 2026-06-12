# Screenshots & media

Drop screenshots/GIFs here and reference them from the root `README.md`. Suggested set
(the README has commented-out `<img>` tags ready for these names):

| File | Shows |
| ---- | ----- |
| `runtah-map.png` | The radial **Runtah Map** sunburst on a real scan |
| `treemap.png` | The squarified **treemap** view |
| `analysis.png` | An analysis view (Largest / Duplicates / File Types) |
| `onboarding.png` | The first-run onboarding screen |
| `runtahio-demo.gif` | Optional: scan → drill → switch view (short loop) |

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

GitHub's link-unfurl image (Open Graph) is **not** set by these files — upload a 1280×640
image under **Settings → General → Social preview** (web UI only; there's no REST API for
it). A cropped Runtah Map on a dark background makes a good one.
