#!/bin/bash
# Builds Release and installs LocalTube.app into /Applications (see ADR-003: local signing only).
set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild -project LocalTube.xcodeproj -scheme LocalTube -configuration Release \
  -derivedDataPath build/DerivedData build -quiet
# Quit (not kill) the installed app so it saves where you left off.
osascript -e 'if application id "local.LocalTube" is running then tell application id "local.LocalTube" to quit' || true
while pgrep -f "^/Applications/LocalTube.app/" >/dev/null; do sleep 0.2; done
rm -rf /Applications/LocalTube.app
ditto build/DerivedData/Build/Products/Release/LocalTube.app /Applications/LocalTube.app
echo "installed /Applications/LocalTube.app"
