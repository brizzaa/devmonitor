#!/bin/bash
# Assemble a release DevMonitor.app on macOS and ad-hoc sign it.
# Usage (from anywhere): scripts/build-app.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: scripts/build-app.sh must be run on macOS (this host is $(uname -s))." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift was not found. Install Xcode 15 or later, or a Swift 5.9+ toolchain, and make sure it is on PATH." >&2
  exit 1
fi

if ! command -v codesign >/dev/null 2>&1; then
  echo "error: codesign was not found. Install the Xcode command line tools (xcode-select --install)." >&2
  exit 1
fi

echo "==> swift build -c release --product DevMonitor"
swift build -c release --product DevMonitor

BIN_DIR="$(swift build -c release --product DevMonitor --show-bin-path)"
BINARY="${BIN_DIR}/DevMonitor"

if [[ ! -e "$BINARY" ]]; then
  echo "error: SwiftPM did not produce ${BINARY}" >&2
  exit 1
fi

# Follow symlinks so the bundle contains the real Mach-O, not a link into .build.
resolved="$BINARY"
while [[ -L "$resolved" ]]; do
  target="$(readlink "$resolved")"
  case "$target" in
    /*) resolved="$target" ;;
    *) resolved="$(cd "$(dirname "$resolved")" && pwd)/${target}" ;;
  esac
done

if [[ ! -f "$resolved" || ! -x "$resolved" ]]; then
  echo "error: ${resolved} is not an executable file." >&2
  exit 1
fi

APP="${ROOT}/dist/DevMonitor.app"
rm -rf "$APP"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

echo "==> install ${resolved}"
cp -p "$resolved" "${APP}/Contents/MacOS/DevMonitor"
chmod 755 "${APP}/Contents/MacOS/DevMonitor"

# SwiftPM drops resource bundles next to the product. Bundle.module looks
# beside the executable; Contents/Resources is the normal app location.
# An unmatched glob stays literal, so a missing suffix is skipped.
copy_resources() {
  local suffix="$1"
  local destination="$2"
  local path base
  for path in "${BIN_DIR}"/${suffix}; do
    [[ -e "$path" ]] || continue
    base="$(basename "$path")"
    case "$base" in
      '*'|'*'.bundle|'*'.resources) continue ;;
    esac
    echo "==> resource ${base} -> ${destination#"${APP}/"}"
    rm -rf "${destination}/${base}"
    cp -R "$path" "${destination}/${base}"
  done
}

copy_resources '*.bundle' "${APP}/Contents/MacOS"
copy_resources '*.bundle' "${APP}/Contents/Resources"
copy_resources '*.resources' "${APP}/Contents/Resources"

ICONSET="${ROOT}/Assets/AppIcon.iconset"
if [[ -d "$ICONSET" ]]; then
  if command -v iconutil >/dev/null 2>&1; then
    echo "==> iconutil AppIcon.icns"
    iconutil -c icns "$ICONSET" -o "${APP}/Contents/Resources/AppIcon.icns"
  else
    echo "warning: iconutil not found; the app will use the default icon." >&2
  fi
fi

cat > "${APP}/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>DevMonitor</string>
	<key>CFBundleExecutable</key>
	<string>DevMonitor</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleIdentifier</key>
	<string>com.devmonitor.DevMonitor</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>DevMonitor</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

printf 'APPL????' > "${APP}/Contents/PkgInfo"

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "${APP}/Contents/Info.plist" >/dev/null
fi

echo "==> codesign --force --deep -s -"
codesign --force --deep -s - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "Built ${APP}"
