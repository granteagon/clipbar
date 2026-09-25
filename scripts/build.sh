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
mkdir -p dist/ClipBar.app/Contents/MacOS
cp "$bin" dist/ClipBar.app/Contents/MacOS/ClipBar
cp Resources/Info.plist dist/ClipBar.app/Contents/Info.plist
codesign --force --sign "${SIGNING_IDENTITY:--}" --options runtime dist/ClipBar.app
printf 'Built %s/dist/ClipBar.app\n' "$PWD"
