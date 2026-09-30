#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "--universal" ]]; then
  swift build -c release --arch arm64 --arch x86_64
  bin="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/ClipBar"
else
  swift build -c release
  bin="$(swift build -c release --show-bin-path)/ClipBar"
fi
output_dir="${OUTPUT_DIR:-dist}"
mkdir -p "$output_dir/ClipBar.app/Contents/MacOS"
cp "$bin" "$output_dir/ClipBar.app/Contents/MacOS/ClipBar"
cp Resources/Info.plist "$output_dir/ClipBar.app/Contents/Info.plist"
# Keep local app identity stable across rebuilds when a development certificate exists.
identity="${SIGNING_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  identity="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ {print $2; exit}')"
fi
codesign --force --sign "${identity:--}" --options runtime "$output_dir/ClipBar.app"
printf 'Built %s/ClipBar.app\n' "$output_dir"
