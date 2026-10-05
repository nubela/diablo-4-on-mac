#!/bin/bash
# Packs dist/D4Mac.app into dist/D4Mac.dmg (drag-to-Applications) and dist/D4Mac.zip.
set -euo pipefail
cd "$(dirname "$0")/.."

app="dist/D4Mac.app"
[[ -d "$app" ]] || { echo "Run scripts/build-app.sh first." >&2; exit 1; }

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp -R "$app" "$stage/"
ln -s /Applications "$stage/Applications"

rm -f dist/D4Mac.dmg dist/D4Mac.zip
hdiutil create -volname "D4Mac" -srcfolder "$stage" -fs HFS+ -format UDZO -ov dist/D4Mac.dmg
ditto -c -k --keepParent "$app" dist/D4Mac.zip
echo "Built dist/D4Mac.dmg and dist/D4Mac.zip"
