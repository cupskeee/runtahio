#!/bin/bash
#
# benchmark.sh — measure Runtahio's metadata-only scanner against synthetic file trees.
#
# It generates trees of N empty files (file *count* drives a metadata scan, not bytes),
# runs the RuntahioBench harness on each, and prints a Markdown table of scan time and
# peak resident memory. Trees are created under a temp dir and removed afterward.
#
# Usage: ./Scripts/benchmark.sh [count1 count2 ...]   (default: 10000 100000 250000)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

COUNTS=("$@")
if [ ${#COUNTS[@]} -eq 0 ]; then COUNTS=(10000 100000 250000); fi

echo "==> Building RuntahioBench (release)…" >&2
swift build -c release --product RuntahioBench >/dev/null
BIN="$(swift build -c release --show-bin-path)/RuntahioBench"

WORK="$(mktemp -d /tmp/runtahio-bench.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

gen() { # gen <dir> <count> — create <count> empty files across a nested tree
  python3 - "$1" "$2" <<'PY'
import os, sys
root, total = sys.argv[1], int(sys.argv[2])
per, made, d = 200, 0, 0
while made < total:
    sub = os.path.join(root, f"g{d // 50}", f"s{d}")
    os.makedirs(sub, exist_ok=True)
    n = min(per, total - made)
    for i in range(n):
        open(os.path.join(sub, f"f{i}.dat"), "w").close()
    made += n
    d += 1
PY
}

printf '\n| Synthetic target | Files | Folders | Scan time | Peak memory |\n'
printf '|---|---:|---:|---:|---:|\n'
for c in "${COUNTS[@]}"; do
  tree="$WORK/tree_$c"
  echo "==> Generating $c files…" >&2
  gen "$tree" "$c"
  echo "==> Scanning…" >&2
  out="$("$BIN" "$tree")"
  files=$(echo "$out" | sed -E 's/.*files=([0-9]+).*/\1/')
  folders=$(echo "$out" | sed -E 's/.*folders=([0-9]+).*/\1/')
  wall=$(echo "$out" | sed -E 's/.*wall=([0-9.]+).*/\1/')
  peak=$(echo "$out" | sed -E 's/.*peakMB=([0-9]+).*/\1/')
  label=$(python3 -c "print(f'{$c:,} files')")
  printf '| %s | %s | %s | %ss | %s MB |\n' "$label" "$files" "$folders" "$wall" "$peak"
  rm -rf "$tree"
done

echo ""
echo "Metadata-only scan; never reads file contents. Numbers vary by machine and disk."
