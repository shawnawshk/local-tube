#!/bin/bash
# Builds Release with the given version and packages build/LocalTube-<version>.dmg
# (the app plus an Applications shortcut). Used by .github/workflows/release.yml.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION=${1:?usage: make-dmg.sh <version>}
xcodebuild -project LocalTube.xcodeproj -scheme LocalTube -configuration Release \
  -derivedDataPath build/DerivedData MARKETING_VERSION="$VERSION" build -quiet

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto build/DerivedData/Build/Products/Release/LocalTube.app "$STAGE/LocalTube.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "LocalTube $VERSION" -srcfolder "$STAGE" -format UDZO -ov "build/LocalTube-$VERSION.dmg"
echo "built build/LocalTube-$VERSION.dmg"
