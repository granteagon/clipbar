#!/bin/bash
set -euo pipefail
version="${1:?Usage: make-cask.sh VERSION ARCHIVE}"
archive="${2:?Usage: make-cask.sh VERSION ARCHIVE}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected x.y.z version' >&2; exit 1; }
checksum="$(shasum -a 256 "$archive" | awk '{print $1}')"
cat <<CASK
cask "clipbar" do
  version "$version"
  sha256 "$checksum"

  url "https://github.com/granteagon/clipbar/releases/download/v#{version}/ClipBar.zip"
  name "ClipBar"
  desc "Local clipboard history with managed retention controls"
  homepage "https://github.com/granteagon/clipbar"

  depends_on macos: ">= :ventura"
  app "ClipBar.app"

  zap trash: [
    "~/Library/Application Support/ClipBar",
    "~/Library/Preferences/com.granteagon.ClipBar.plist",
  ]
end
CASK
