#!/bin/bash
# Renders scripts/AppIcon.svg into the AppIcon asset catalog PNGs.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=LocalTube/Assets.xcassets/AppIcon.appiconset
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/render.swift" <<'EOF'
import AppKit
let args = CommandLine.arguments
guard let svg = NSImage(contentsOfFile: args[1]) else { fatalError("cannot load \(args[1])") }
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
svg.draw(in: NSRect(x: 0, y: 0, width: 1024, height: 1024))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
EOF

swiftc -o "$TMP/render" "$TMP/render.swift"
"$TMP/render" scripts/AppIcon.svg "$OUT/icon_1024.png"
for size in 16 32 64 128 256 512; do
  sips -z $size $size "$OUT/icon_1024.png" --out "$OUT/icon_$size.png" >/dev/null
done
echo "icons written to $OUT"
