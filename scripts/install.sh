#!/bin/bash
# Builds Release and installs LocalTube.app into /Applications (see ADR-003: local signing only).
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project LocalTube.xcodeproj -scheme LocalTube -configuration Release \
  -derivedDataPath build/DerivedData build -quiet
pkill -x LocalTube || true
rm -rf /Applications/LocalTube.app
ditto build/DerivedData/Build/Products/Release/LocalTube.app /Applications/LocalTube.app
echo "installed /Applications/LocalTube.app"
